## ⭐ 当前状态：v0.9.0 已审计并发布
M27+M28 已收口并发布为 v0.9.0：扫描问题态、专业清理结果页、墨韵 Studio 设计系统 v2，以及本轮审计确认的 3 项中等完整性问题均已修复。核心测试 174/30 全绿；Debug 和 arm64+x86_64 通用 Release 构建通过；Cask 已同步 0.9.0 与发布 ZIP 的 SHA-256。
**下一轮候选**（按价值）：① App test target（设置持久化、历史状态迁移、Uninstaller Docker guard）；② `CleanupExecutor` 收敛重复清理循环；③ DockerCLI 持续读取 stdout/stderr，避免异常大输出填满 Pipe；④ 正式 Developer ID 签名与公证；⑤ ⌘K / i18n / 重复文件 / 定时提醒。

# NEXT STEPS

## 关键决策(已确认,2026-07-05)
1. **技术栈**:Swift 原生开发。
2. **形态**:图形界面 Mac App。
3. **功能范围(MVP)**:垃圾/缓存清理 + 系统状态监控。**已实现并交付。**
4. **命名**:净山(Jingshan)。
5. **平台范围**:仅 macOS。
6. **非沙盒 + ad-hoc 本机签名**（已落地，`net.kongshan.jingshan`）。正式 Developer ID 签名/公证留给用户自己决定是否要做。
7. **工程生成工具 = xcodegen**，真源是 `project.yml`。

## ⭐ 立即的下一步：观察 v0.9.0 实际使用反馈

重点观察：完全磁盘访问未授权时的问题提示、清理搜索/筛选、Docker Desktop 启停边界、数据卷身份变化后的拒绝提示、历史恢复与受保护路径配置异常提示。若无真实问题，不继续扩扫描范围或重构删除链路。

开发验证仍建议使用 `swift test --scratch-path /private/tmp/<独立目录>`，避免仓库旧 `.build` 的绝对路径缓存。发布 ZIP：`Jingshan-0.9.0.zip`，SHA-256 `a22ce2ef6d5bb3804c3e2cae0e91f4a31f70ee271546a98b6c06f085b615ab27`。

后续仅在有实测需求时再做：App 测试 target、更细粒度的枚举错误、AI 模型/Group Containers/系统级残留。暂不引入 `CleanupExecutor`、共享指标总线或新扫描 DSL，避免在现有行为一致且无性能证据时扩大架构。

## （历史）M25 视觉批次与 A5.2 强力模式
用户提供"新增功能+精修"提示词（Part A 7 项 + Part B 建议 + Part C）。本轮（M25）做了**视觉统一批次**：A2 顶部分段胶囊导航（matchedGeometryEffect 滑动）、Part C（卸载刷新改中性、清理/各模块复选框系统蓝→模块色、`ModuleCheckboxToggleStyle`）、A5.1 来源字典（补"未识别来源"标签，其余 M6 已覆盖）。已装机、146 测试通过、离屏渲染确认，**未提交未发版**。
**"新增功能+精修"提示词的 Part A/B/C 核心已全部落地**（M24→M26）：A6/A2 视觉统一、A5.1 来源字典、A5.2 强力模式、A1 累计历史、B2 一键恢复、**B1 大文件查找（新模块）、A4 菜单栏托盘、A3 状态监控扩展（系统信息/每核心/Top 进程；GPU/温度/风扇按无可靠公开 API 优雅缺席）**、Part C 小修。151 测试通过、已装 `/Applications/净山.app`。**这一大批（M24 FDA 引导起，到 M26）全部未提交、未发版——可一起发 0.8.1。**
**后续可选增强**（提示词里较小或明确降级的项）：A3 点击卡片展开详情 / 内存 swap 分解 / 网络分接口+连接数 / 磁盘 SMART；大文件模块专属水墨诗句；B3/B4/B5（重复文件、定时提醒）、B6 英文 i18n、B7 命令面板 ⌘K；GPU/温度/风扇需私有 API（实验性另立里程碑）。

## （历史）确认 M24 是否发 0.8.1
M24 已完成（全局 FDA 引导 + 首启欢迎 + 「打开废纸篓」入口 + 体积改实际占用 allocatedSize + hero 打磨），146 测试通过、装机冒烟无 crash，但**改动未提交、未发版**。等用户走查（尤其首启欢迎/FDA 横幅在真实窗口的观感、"打开系统设置"深链、"授权后重启"）后，决定是否 `commit`+发 **0.8.1**（发版流程见下）。真机需授予净山「完全磁盘访问权限」后扫描结果才准。

## （历史）走查 v0.8.0
M23（P0 扫描修复 + P1 水墨精细化 + P2 排版对齐）**全部完成、已提交推送、v0.8.0 已发布上线**（`brew upgrade --cask kongshan-0924/jingshan/jingshan` 实测从 0.7.0 升到 0.8.0 通过）。等用户打开 `/Applications/净山.app` 走查：构建产物扫描进度反馈、hero 山形剪影、无系统蓝、首页磁贴等高+概览三列、状态页副标题单行+Bento 底对齐、卸载搜索框在内容区、顶部"…"菜单展开。若某处排版还想微调，直接指出具体页面/元素，下个版本（0.8.1/0.9.0）继续修。深色模式配色仍是 M20 估的第一版，值得一并反馈。

**注意仓库已迁移到 `kongshan-0924/jingshan`**（旧 `Ks-Ht` 地址 GitHub 重定向；tap 名、Cask、README 都已改到新地址）。发新版流程见下方（改版本号→构建→ditto→算 sha256→gh release→更 Cask→push→brew 冒烟）。

## 实施进度：M1-M23 全部完成（P0+P1+P2）
（M22 修三处真机反馈：Docker 稀疏文件误报整盘容量、0 值 "Zero KB"、首页"立即清理"误删暗示。M23 分两步交付——P0：构建产物扫描加目录选择器+实时进度+四态流程；P1：hero 换成单条干净山形剪影+彻底去系统蓝；P2：首页磁贴等高+系统概览三等分网格、状态页健康度副标题独占整行不换行+Bento 卡片同行底对齐、卸载搜索框从标题栏移入内容区、顶部"…"改成真正的 Menu、logo↔标签间距收紧。详见 docs/HANDOFF.md 对应条目。以下段落是 M20/M21 时点写的，模块功能本身没变。）

## （历史）实施进度：M1-M20 全部完成
详见 docs/HANDOFF.md 的完整记录（含 M7 审计 9 项 + M10 审计 3 项 + M12 审计 4 项 + M18 审计 5 项 + M20 审计 5 项发现与修复，各模块设计要点，以及 M13/M14/M20 视觉设计系统说明、M19 Homebrew 分发设计要点）。App 已安装在 `/Applications/净山.app`，146 个单元测试全绿。当前功能：清理（分组，默认只勾选 App缓存/开发工具/浏览器三组）、Docker（宿主数据+运行时资源+未使用网络，Docker 停止时也能用）、项目构建产物清理（Purge，覆盖 Node/Rust/Java/Scala/Swift/Python/Go/Gradle/CocoaPods/Turborepo/Nuxt/Angular）、应用卸载器（Uninstaller，应用本体+残留文件含登录启动项，只有安全档默认勾选，原生搜索+排序）、状态监控（Bento 网格：健康分/CPU/内存/磁盘/网络/电池，各卡片带 60 秒趋势图）、设置页（受保护路径+预览模式+构建产物扫描目录）。视觉上先后做过 M13（一致性配色）、M14（路径式侧边栏+弧形仪表盘+动态非对称状态页）、**M20（整体重构为水墨山水设计系统，五个模块统一 Hero 模板+专属意象诗句，同时修复了真机反馈的 RingGauge 裁切 bug，并补齐了 VoiceOver/Reduce Motion/Dynamic Type 支持）**三轮优化。**项目已开源在 `https://github.com/Ks-Ht/jingshan`（公开仓库），发布了 `v0.7.0` GitHub Release，可通过 `brew tap ks-ht/jingshan https://github.com/Ks-Ht/jingshan && brew install --cask jingshan` 一步安装（M19）。**

## 如果继续迭代，建议顺序
1. **用户先看一遍 M20 水墨设计系统的实际效果**（协助开发的一方没有 Accessibility/Screen Recording 权限，SwiftUI 实现本身没有被截图验证过）——五个模块的水墨意象+诗句头部、修复后的 RingGauge（应为完整圆环，之前反馈的裁切/数字溢出问题应该已经解决）、Status 页 Bento 网格+趋势图、四个模块新的逐项审查确认弹窗。深色模式色值是估的第一版，尤其值得反馈。不满意可以具体指出哪一页/哪个元素需要调整，比笼统反馈"不好看"更容易改。
2. 继续走查功能本身：卸载应用页（建议先用不重要的小工具类应用测试一遍完整流程）、`AppCacheCatalog.json` 里没覆盖到的常见 App（发现一个加一条 JSON 记录即可，不用改代码逻辑）、Docker 页面在真实有容器/镜像/卷的机器上展示是否准确。
3. 更大的视觉/体验改动（M13/M14/M20 都故意没做）：换图标、菜单栏 MenuBarExtra HUD（M20 文档里明确标注的"加分项"，这次跳过）、GPU/温度/风扇监控（M20 评估后确认没有可靠公开 API，需要单独评估要不要接受私有 API 的脆弱性风险）。
4. 正式分发：申请 Apple Developer Program → Xcode 里配置 Team/Developer ID 证书 → `notarytool` 公证 → 打 DMG（M19 已确认用户目前接受 ad-hoc 签名的 Gatekeeper friction，这一条不是当前的优先级，只在用户主动想升级分发方式时再做）。
5. **（M19）如果要发新的 Homebrew 版本**：流程见 `docs/HANDOFF.md`"下一步该做什么"第 0 条——改版本号→Release 构建→`ditto` 打包→算新 `sha256`→发 GitHub Release→同步更新 `Casks/jingshan.rb` 的 `version`/`sha256`→push→本地冒烟验证 `brew upgrade --cask jingshan`。这几步目前全是手动操作，没有 CI/CD 自动化，容易漏更新 sha256 导致安装失败。
6. **（M20 新增）Dynamic Type 需要用户实际把系统文字调到最大档验证一遍**：目前只做到了代码模式审查（`RingGauge` 已经改成 `@ScaledMetric`），没有真机截图验证过极端字号下是否有裁切/重叠，跟本项目一直存在的截图权限限制是同一个问题。
7. 其余新功能（按需选择，讨论过但用户暂时选择先做 UI 优化+功能完善，还没定下一个做哪个）：
   - 磁盘空间分析（`mo analyze`，Mole 桌面版叫"Analyze"/treemap）—— 需要新的可视化浏览 UI（类似 DaisyDisk），比现有 List 展示复杂得多。
   - 系统优化维护（`mo optimize`）——涉及需要 sudo 的操作，安全设计需要专门评估（当前 `CriticalPathDenylist` 刻意没覆盖这类场景，授权/认证方式如 Touch ID 还是密码提权也需要和用户确认）。
   - Uninstaller 模块可扩展：`~/Library/Group Containers`（v1 故意跳过，group id 与 bundle id 无简单对应关系）；如果用户要卸载 Parallels/UTM/VMware 等其他虚拟化工具，需评估是否要像 Docker 一样加针对性存活检测（当前只覆盖 Docker 这一个已验证案例）。
   - Docker 模块 daemon 侧网络清理已实现（M17），可以进一步扩展的是 `~/.docker` 缓存子目录的精细化处理（需先确认哪些子目录纯缓存、哪些是配置，`~/.docker` 目前整体不碰）。

## 维护提醒（M7 审计发现，务必留意）
新增任何 `DevToolCacheScanner`/`BrowserCacheScanner` 里直接指向 `~/Library/Caches` 子目录的位置时，**必须**同步把对应文件夹名加进 `topLevelCacheNamesToExcludeFromGenericScan`（两个 scanner 各自维护一份，`UserCacheScanner` 取并集）。忘记这一步会导致该文件夹在"用户缓存"和对应专项分类里被重复展示、重复计入总大小——M7 审计中发现 SwiftPM/Homebrew 缓存就因为这个疏漏被漏排除过，M17 新增 pip 缓存位置时也同步做了处理，机制本身仍是人工维护，没有编译期/运行时保障。

## 已知限制（非阻塞，供后续参考）
- 协助开发的 Agent 目前无法对**原生 App**截图或做 Accessibility UI 验证（缺少"屏幕录制"和"辅助功能"权限）。M14 用 HTML mockup + 本地预览服务器的方式部分绕过了这个限制（验证了设计方向），但最终 SwiftUI 实现仍未被截图验证。**M20 的 RingGauge 裁切 bug 是这个限制真实代价的直接证据**——那个 bug 从 M14 起存在了好几个里程碑，靠"编译通过+单测全绿+冒烟无崩溃"这条验证链完全没被发现，是用户自己用出来反馈的。如果用户希望以后能自动化验证，可以考虑把这两个权限授予跑 Claude Code 的终端 App。
- Metrics 模块的内存/网络口径 M16 已校正过（更接近 Activity Monitor 的口径），但仍是近似——不区分 App/Wired/Compressed 分别多少，网络仍是"所有物理网卡求和"而非"识别默认路由网卡"，Thunderbolt Bridge 作为主力网络连接会被误判为虚拟网卡漏统计（极罕见场景）。
- Docker 模块构建缓存作为单一聚合项处理，不支持逐条清理；"未使用自定义网络"清理评级为 caution+默认不勾选，且已用真机验证确认（`docker network prune` 不会因为存在非运行态容器引用而保护网络，`docker compose stop` 场景确实可能被误清），这是经过验证的正确评级，不需要再放宽。
- **（M19）ad-hoc 签名 + 未公证是当前分发方式的固有限制，用户已知情接受**：`spctl -a` 判定固定是 `rejected`；Cask 的 `postflight` 自动清除 quarantine 属性能让普通 `brew install` 后直接双击打开，但如果以后要分享给用户之外的人，或者想彻底消除任何 Gatekeeper 相关的疑虑，仍需走 Developer ID + 公证（需要用户自己的 Apple Developer Program 账号，$99/年）。
- **（M20）GPU/温度/风扇监控刻意不做**：没有 Apple 公开支持的 API，只能靠未文档化、随机型/系统版本差异很大的私有接口（`IOAccelerator`/SMC），不想在一个"数据安全第一"的工具里塞一个可能读错或崩溃的功能。
- **（M20）Dynamic Type 只验证到代码模式层面**：`RingGauge` 已用 `@ScaledMetric`，但没有真机调大字号截图验证过，跟上面第一条截图权限限制是同一个问题。
- **（M20）`ResultToast` 组件已建好但没有实际接入任何调用点**：四个模块"操作完成"提示依然是原有的模态 `.alert()`，这是刻意保留（模态强制确保"跳过/失败了几项"这类安全相关数字被看到），不是忘记接线。

## 2026-07-13 补充

（2026-07-31 复核：现场 swift test 167/30 全绿，工作树 58 文件未提交，Cask 仍 0.8.1。）

当前优先级不变：先由用户走查本地 M27/v0.9.0，再决定是否提交和发布。继续开发前应保留现有工作树，先运行 `cd JingshanCore && swift test`；涉及 App 源文件结构时再运行 `xcodegen generate` 与 Debug/Release 构建验证。
