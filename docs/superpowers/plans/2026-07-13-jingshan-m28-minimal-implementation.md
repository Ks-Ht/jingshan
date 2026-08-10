# Jingshan M28 Minimal Audit Fixes and UI Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复已审计确认的扫描可信度、安全覆盖、恢复与扫描竞态问题，并用现有墨韵设计系统完成清理页的专业化交互闭环。

**Architecture:** 复用现有 `CategoryScanning`、`ScanCategory`、`ProtectionEvaluator`、`DeletionEngine` 和 SwiftUI 设计系统；只给现有类型增加完成这批需求所需的最小状态。遵循 ponytail full：不建立单实现工厂、规则 DSL、共享指标总线或尚无失败证据的 `CleanupExecutor`，删除安全与可访问性不精简。

**Tech Stack:** Swift 6、SwiftUI、Foundation、Swift Testing、xcodegen、Xcode 26

---

## 文件范围

- 修改扫描模型与帮助器：`JingshanCore/Sources/JingshanCore/Scanning/ScanTypes.swift`、`ScanningSupport.swift`
- 修改现有扫描器：`UserCacheScanner.swift`、`UserLogScanner.swift`、`TrashScanner.swift`、`BrowserCacheScanner.swift`、`DevToolCacheScanner.swift`、`DeepCacheScanner.swift`
- 修改保护与恢复根因：`Safety/ProtectionEvaluator.swift`、`Safety/DeletionEngine.swift`、`History/CleanupRestore.swift`
- 修改卸载覆盖：`Uninstaller/ResidualLocationRule.swift`、`Uninstaller/ResidualFileScanner.swift`
- 修改 App 状态与 UI：`Features/Clean/CleanViewModel.swift`、`CleanView.swift`、`CleanGroupSectionView.swift`、`Features/Shared/DesignSystem/CategoryRow.swift`、`Features/Purge/PurgeViewModel.swift`、`Features/LargeFiles/LargeFilesViewModel.swift`
- 修改现有对应测试文件；不新增第三方依赖。

### Task 1: 扫描不完整状态

**Files:**
- Modify: `JingshanCore/Sources/JingshanCore/Scanning/ScanTypes.swift`
- Modify: `JingshanCore/Sources/JingshanCore/Scanning/ScanningSupport.swift`
- Modify: `JingshanCore/Sources/JingshanCore/Scanning/UserCacheScanner.swift`
- Modify: `JingshanCore/Sources/JingshanCore/Scanning/UserLogScanner.swift`
- Modify: `JingshanCore/Sources/JingshanCore/Scanning/TrashScanner.swift`
- Test: `JingshanCore/Tests/JingshanCoreTests/UserCacheScannerTests.swift`

- [x] **Step 1: 写失败测试**

在 `UserCacheScannerTests` 增加不可读根目录测试，断言扫描不是“成功的空结果”：

```swift
@Test("存在但无法列出的缓存目录会报告扫描问题")
func reportsUnreadableRoot() async throws {
    let scratch = try TestFixtures.makeScratchDirectory()
    defer { TestFixtures.removeIfNeeded(scratch) }
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: scratch.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scratch.path) }

    let category = await UserCacheScanner(directoryPath: scratch.path, excludedNames: []).scan()

    #expect(category.items.isEmpty)
    #expect(!category.issues.isEmpty)
}
```

- [x] **Step 2: 运行测试确认失败**

Run: `cd JingshanCore && swift test --filter UserCacheScannerTests`

Expected: FAIL，`ScanCategory` 尚无 `issues`。

- [x] **Step 3: 最小实现问题模型和根目录错误传播**

在 `ScanTypes.swift` 增加：

```swift
public struct ScanIssue: Identifiable, Equatable, Sendable {
    public let id: String
    public let message: String
}
```

给 `ScanCategory` 增加默认空数组的 `issues`。将 `scanImmediateChildren` 返回值改为命名元组 `(items: [ScannableItem], issues: [ScanIssue])`；目录不存在仍是正常空结果，`contentsOfDirectory` 抛错则生成一条用户可读问题。三个调用方直接传入 `issues`，不创建新的扫描结果层。

- [x] **Step 4: 运行测试确认通过**

Run: `cd JingshanCore && swift test --filter 'UserCacheScannerTests|UserLogScannerTests|TrashScannerTests'`

Expected: PASS。

### Task 2: 已知安全缓存覆盖与 Apple 保护根因

**Files:**
- Modify: `JingshanCore/Sources/JingshanCore/Scanning/BrowserCacheScanner.swift`
- Modify: `JingshanCore/Sources/JingshanCore/Scanning/DeepCacheScanner.swift`
- Modify: `JingshanCore/Sources/JingshanCore/Safety/ProtectionEvaluator.swift`
- Modify: `JingshanCore/Sources/JingshanCore/Safety/DeletionEngine.swift`
- Test: `JingshanCore/Tests/JingshanCoreTests/BrowserCacheScannerTests.swift`
- Test: `JingshanCore/Tests/JingshanCoreTests/ProtectionEvaluatorTests.swift`
- Test: `JingshanCore/Tests/JingshanCoreTests/DeletionEngineTests.swift`

- [x] **Step 1: 写浏览器 Profile 与保护白名单失败测试**

```swift
@Test("只发现 Chromium profile 中的已知缓存子目录")
func findsKnownChromiumProfileCaches() async throws {
    let home = try TestFixtures.makeScratchDirectory()
    defer { TestFixtures.removeIfNeeded(home) }
    let profile = home.appendingPathComponent("Library/Application Support/Google/Chrome/Profile 1")
    try FileManager.default.createDirectory(at: profile.appendingPathComponent("Code Cache"), withIntermediateDirectories: true)
    try TestFixtures.writeFile(at: profile.appendingPathComponent("History"), contents: "keep")

    let category = await BrowserCacheScanner(homeDirectory: home.path).scan()

    #expect(category.items.contains { $0.path.hasSuffix("Profile 1/Code Cache") })
    #expect(!category.items.contains { $0.path.hasSuffix("History") })
}

@Test("Safari 仅在明确缓存路径豁免静态保护")
func safariCacheBypassesStaticProtectionOnlyForCachePath() {
    let evaluator = ProtectionEvaluator(
        protectedApps: .init(entries: [.init(bundleIdentifierPattern: "com.apple.*", reason: "test")]),
        runningChecker: FakeRunningApplicationChecker()
    )
    #expect(evaluator.evaluate(bundleIdentifier: "com.apple.Safari", path: "/Users/a/Library/Caches/com.apple.Safari") == .notProtected)
    guard case .staticallyProtected = evaluator.evaluate(bundleIdentifier: "com.apple.Safari", path: "/Applications/Safari.app") else {
        Issue.record("Safari app must stay protected")
        return
    }
}
```

- [x] **Step 2: 运行测试确认失败**

Run: `cd JingshanCore && swift test --filter 'BrowserCacheScannerTests|ProtectionEvaluatorTests|DeletionEngineTests'`

Expected: FAIL，尚无 Profile 发现和 path-aware 保护。

- [x] **Step 3: 实现受约束 Profile 发现**

在 `BrowserCacheScanner` 内用 `FileManager.contentsOfDirectory` 枚举 `Default` 与 `Profile ` 前缀目录，只拼接这组固定名称：

```swift
private static let chromiumCacheNames = [
    "Cache", "Code Cache", "GPUCache", "ShaderCache", "GrShaderCache", "DawnCache"
]
```

覆盖 Chrome、Edge、Arc 的既有 Application Support 根；不遍历 History、Cookies、Login Data、Extensions。每个候选仍生成普通 `ScannableItem`，继续走现有删除引擎。

在 `DeepCacheScanner` 仅追加明确可再下载的 Corepack、Playwright、Deno 缓存路径；AI 模型和未知 `Application Support` 不加入，因为其用户价值与可再生成性没有统一保证。

- [x] **Step 4: 在共享保护入口做最窄豁免**

把 `ProtectionEvaluator.evaluate` 改为接收可选 `path`。仅当 bundle id 为 `com.apple.Safari` 且标准化路径位于以下两个根时跳过静态保护，再继续检查运行状态：

```swift
~/Library/Caches/com.apple.Safari
~/Library/Containers/com.apple.Safari/Data/Library/Caches
```

`CleanViewModel` 与 `DeletionEngine` 都传实际路径，确保 UI 预判和执行结果一致；其他 `com.apple.*` 保持不可覆盖。

- [x] **Step 5: 运行测试确认通过**

Run: `cd JingshanCore && swift test --filter 'BrowserCacheScannerTests|ProtectionEvaluatorTests|DeletionEngineTests|StrongModeScanTests'`

Expected: PASS。

### Task 3: 卸载残留补齐但保持保守

**Files:**
- Modify: `JingshanCore/Sources/JingshanCore/Uninstaller/ResidualLocationRule.swift`
- Modify: `JingshanCore/Sources/JingshanCore/Uninstaller/ResidualFileScanner.swift`
- Test: `JingshanCore/Tests/JingshanCoreTests/ResidualLocationRuleTests.swift`
- Test: `JingshanCore/Tests/JingshanCoreTests/ResidualFileScannerTests.swift`

- [x] **Step 1: 写失败测试**

验证 ByHost plist、Cookies、Application Scripts、DiagnosticReports 以及内容引用应用路径的用户 LaunchAgent；同时验证相似名字不匹配、系统级目录不进入结果。

```swift
@Test("finds an Application Scripts directory by exact bundle id")
func findsApplicationScripts() async throws {
    let home = try TestFixtures.makeScratchDirectory()
    defer { TestFixtures.removeIfNeeded(home) }
    let path = home.appendingPathComponent("Library/Application Scripts/com.example.app")
    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)

    let found = await ResidualFileScanner().scanResiduals(for: app(), homeDirectory: home.path)

    #expect(found.contains { $0.path == path.path && $0.tier == .caution })
}
```

- [x] **Step 2: 运行测试确认失败**

Run: `cd JingshanCore && swift test --filter 'ResidualLocationRuleTests|ResidualFileScannerTests'`

Expected: FAIL，新位置尚未覆盖。

- [x] **Step 3: 追加精确规则和两个受限目录扫描**

`ResidualLocationRule.defaultRules` 追加 Cookies 与 Application Scripts 的 bundle-id 精确规则，均为 `.caution`。ByHost 与 DiagnosticReports 需要枚举目录，新增两个私有方法，只接受：

```swift
entry.hasPrefix(app.bundleIdentifier + ".") && entry.hasSuffix(".plist")
entry.hasPrefix(app.displayName + "_") && allowedDiagnosticSuffixes.contains(pathExtension)
```

LaunchAgent 内容匹配只解析 plist 的 `Program` 和字符串型 `ProgramArguments`，要求标准化字符串等于应用路径或位于 `App.app/Contents/` 内；解析失败即忽略。系统级路径和 Group Containers 不进入自动候选。

- [x] **Step 4: 运行测试确认通过**

Run: `cd JingshanCore && swift test --filter 'ResidualLocationRuleTests|ResidualFileScannerTests'`

Expected: PASS。

### Task 4: 外置卷恢复与旧扫描回调

**Files:**
- Modify: `JingshanCore/Sources/JingshanCore/History/CleanupRestore.swift`
- Modify: `Features/Purge/PurgeViewModel.swift`
- Modify: `Features/LargeFiles/LargeFilesViewModel.swift`
- Test: `JingshanCore/Tests/JingshanCoreTests/CleanupRestoreTests.swift`

- [x] **Step 1: 写恢复失败测试**

使用现有可注入 `trashRoots` 建立一个模拟外置卷 Trash 根，验证根内可恢复、兄弟目录不可恢复：

```swift
let externalTrash = scratch.appendingPathComponent("External/.Trashes/501")
let outside = scratch.appendingPathComponent("External/not-trash/file")
#expect(CleanupRestorer.restore([validItem], trashRoots: [externalTrash.path]).restoredCount == 1)
#expect(CleanupRestorer.restore([outsideItem], trashRoots: [externalTrash.path]).failedCount == 1)
```

- [x] **Step 2: 实现生产环境可信根派生**

当调用方未传 `trashRoots` 时，对每个仍存在的 Trash 项读取 `.volumeURLKey`，只加入：

```swift
volumeURL/.Trashes/<getuid()>
```

同时保留 `~/.Trash`。最终仍使用现有标准化前缀、指纹和目标占用校验，不接受仅因路径中含 `.Trashes` 就可信的记录。

- [x] **Step 3: 给 Purge 和 Large Files 增加与 Clean 相同的 generation**

每次开始/取消扫描递增 `scanGeneration`，进度和完成回调都验证捕获的 generation：

```swift
scanGeneration += 1
let generation = scanGeneration
// callback
guard self.scanGeneration == generation else { return }
// completion
guard !Task.isCancelled, scanGeneration == generation else { return }
```

- [x] **Step 4: 运行核心测试和 Debug 构建**

Run: `cd JingshanCore && swift test --filter CleanupRestoreTests`

Run: `xcodebuild -project Jingshan.xcodeproj -scheme Jingshan -configuration Debug build CODE_SIGNING_ALLOWED=NO`

Expected: PASS / BUILD SUCCEEDED。

### Task 5: 清理页专业交互和无障碍

**Files:**
- Modify: `Features/Clean/CleanViewModel.swift`
- Modify: `Features/Clean/CleanView.swift`
- Modify: `Features/Clean/CleanGroupSectionView.swift`
- Modify: `Features/Shared/DesignSystem/CategoryRow.swift`
- Modify: `App/SnapshotHarness.swift`

- [x] **Step 1: 复用现有结果模型增加轻量筛选**

在 `CleanViewModel` 增加 `query` 与本地 `Filter` 枚举；`filteredDisplayGroups` 只过滤 `displayGroups`，不复制扫描结果或选择状态。筛选项为全部、已选择、需检查、已保护、扫描问题；“需检查”映射默认不选的 CacheGroup。

- [x] **Step 2: 把扫描问题和筛选放进现有页面**

`CleanView` 在 Header 下增加一个紧凑搜索框、原生 `Picker(.segmented)` 和问题横幅。List 使用 `filteredDisplayGroups`；无匹配时显示筛选空态，不能误报“没有垃圾”。

底部操作使用现有 `safeAreaInset(edge: .bottom)`，显示已选数量/容量、废纸篓说明和“检查并清理…”按钮；Header 只保留扫描/取消，避免两个清理按钮竞争。

- [x] **Step 3: 修复重复点击语义与复选框键盘行为**

删除 `CleanGroupSectionView` 外层 `.onTapGesture`，让 chevron Button 成为唯一展开动作。将 `ModuleCheckboxToggleStyle` 的裸手势替换成 plain Button：

```swift
Button {
    configuration.isOn.toggle()
} label: {
    HStack { checkbox; configuration.label }
}
.buttonStyle(.plain)
.disabled(isDisabled)
```

保留外层 Toggle 的标签、值和 VoiceOver 文案，并用键盘实际走查。

- [x] **Step 4: 扩展最小快照入口并构建**

在 `SnapshotHarness` 复用现有 Clean fixture 增加筛选/问题状态，不新建快照框架。

Run: `xcodebuild -project Jingshan.xcodeproj -scheme Jingshan -configuration Debug build CODE_SIGNING_ALLOWED=NO`

Expected: BUILD SUCCEEDED。

### Task 6: 全量验证、记录与范围确认

**Files:**
- Modify: `docs/progress/SESSION_LOG.md`
- Modify: `docs/HANDOFF.md`
- Modify: `docs/PROGRESS.md`
- Modify: `docs/NEXT_STEPS.md`

- [x] **Step 1: 全量核心测试**

Run: `cd JingshanCore && swift test`

Expected: 全部测试通过，数量不少于当前 157。

- [x] **Step 2: Debug/Release 与发布构件检查**

Run: `xcodebuild -project Jingshan.xcodeproj -scheme Jingshan -configuration Debug build CODE_SIGNING_ALLOWED=NO`

Run: `xcodebuild -project Jingshan.xcodeproj -scheme Jingshan -configuration Release build CODE_SIGNING_ALLOWED=NO`

Run: `nm -j <Release-app-binary> | rg SnapshotHarness`

Expected: 两个构建成功，最后命令无输出。

- [x] **Step 3: 视觉和交互走查**

渲染并核对首页、Clean 默认、扫描问题、筛选、确认、深色、大字号；实际走查键盘焦点、取消重扫、废纸篓、部分失败和恢复。发现视觉问题只修改现有设计令牌或现有页面，不新增装饰组件。

- [x] **Step 4: 更新项目记录**

四份记录写清已完成、修改文件、测试结果、当前状态、风险、下一步和接手方式。`SESSION_LOG` 按安全/扫描、UI、验证三个小阶段追加。

## Ponytail 明确跳过

- 不实现通用 `ScanRule` DSL：现有固定数组已能安全表达本轮规则；当规则数量或多模块配置确实造成维护错误时再抽象。
- 不实现共享系统指标总线：审计只有“可能重复采样”，没有性能数据证明值得改。
- 不先做 `CleanupExecutor`：M27 已修复五条执行路径的实际行为；等逐项失败结果需要跨模块复用或再次出现行为分叉时再收敛。
- 不自动清理 AI 大模型、Group Containers、系统级守护进程或未知 Application Support。
