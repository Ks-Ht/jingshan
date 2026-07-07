# HANDOFF

## 已完成什么
净山（Jingshan）v0.7 是一个**可用的产品**：一款 Swift 原生、非沙盒的 macOS 清理与系统监控 App，已构建 Release 版本并安装到 `/Applications/净山.app`，用户机器上正在运行验证。功能：垃圾/缓存清理（分组展示）、Docker 专项清理（宿主数据 + 运行时资源 + 未使用网络，Docker 停止时也能用）、项目构建产物清理（Purge，覆盖 Node/Rust/Java/Scala/Swift/Python/Go/Gradle/CocoaPods/Turborepo/Nuxt/Angular 等生态）、应用卸载器（Uninstaller，应用本体+残留文件含登录启动项，风险分级）、系统状态监控（内存/网络口径已按真机数据校正）、设置页（受保护路径 + 预览模式 + 构建产物扫描目录）。全局视觉已升级为"路径式侧边栏 + 弧形仪表盘 + 动态非对称状态页"的创意布局。145 个单元测试全部通过。

按里程碑：
1. 调研阶段：阅读 https://github.com/tw93/mole 源码，梳理架构要点（见下）。
2. 决策阶段：Swift 原生 App、GUI、MVP=垃圾清理+状态监控、名称=净山、仅 macOS。
3. 规划阶段：EnterPlanMode 产出实现计划并获批准（`/Users/kaysen/.claude/plans/crispy-roaming-dongarra.md`，用户本地路径，不在仓库内）。
4. **M1**：`JingshanCore` 核心安全引擎（路径校验/黑名单/受保护应用名单/用户白名单/统一删除入口/操作日志/Trash 路由）。
5. 环境修复：`xcode-select` 切换到完整 Xcode 26.6（原指向 Command Line Tools）。
6. **M2**：xcodegen 生成非沙盒 App 主工程，接入 JingshanCore；实现扫描模块（5 类扫描器）+ 只读清理列表 UI + 完全磁盘访问权限引导。
7. **M3**：打通删除链路——`ProtectionEvaluator`（受保护应用统一判定，DeletionEngine 内部复用）、`CleanViewModel` 选择状态与清理执行、勾选/预览/二次确认 UI、废纸篓单独清空动作。
8. **M4**：系统状态监控——`JingshanCore` 的 Metrics 模块（CPU/内存/磁盘/网络，基于 Mach/BSD 底层调用）+ `StatusViewModel`（Task 循环采样）+ 四张仪表卡片 UI。
9. **M5（范围内部分）**：生成应用图标（程序化绘制的水墨山峦+新月意象，`/private/tmp/.../scratchpad/generate_icon.swift`，非仓库内容）、Release 构建、安装到 `/Applications/净山.app`。
10. **M6（用户反馈驱动）**：清理列表原先直接平铺展示原始 bundle id（如 `com.microsoft.VSCode.ShipIt`），用户对照 Mole Mac 客户端截图反馈体验太差。新增分类系统——`CacheGroup`（App缓存/开发工具/AI工具/浏览器/通信工具/其他/废纸篓）+ `AppCacheCatalog`（数据驱动的常见 App 友好名称映射表）+ `CacheItemClassifier`（统一归类逻辑），清理列表改为可折叠分组展示（三态复选框+说明文案+展开明细），通信工具分组默认不勾选（保护聊天记录/媒体）。
11. **M7（Docker 模块初版 + 审计）**：新增 Docker 专项清理——独立扫描/清理引擎（容器/悬空镜像/构建缓存/悬空数据卷，均通过 `docker` CLI 子进程操作），风险分级 + 备注，危险项默认不勾选 + 二次确认。审计修复 9 项。
12. **M8（用户要求"Docker 更有强度、不需要 Docker 运行"）**：核心洞察——macOS 上 Docker Desktop 把所有镜像/容器/卷放在一个 Linux 虚拟机的磁盘镜像文件里（`~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw`），所以 daemon 关闭时无法精细删单个镜像，但可以回收整个 VM 磁盘等宿主数据。新增 `DockerHostDataScanner`（扫描 VM 磁盘/日志/应用缓存这些**真实主机路径**，走已审计的 `DeletionEngine` + 回收站，Docker 停止时也能用；VM 磁盘 destructive+默认不勾选+仅 Docker 退出时可回收）。daemon 运行时新增"未使用镜像"清理（`docker rmi` 不加 `-f`，Docker 自身兜底拒删在用镜像）。`DockerRemovalMethod`（`.dockerCommand`/`.filesystemPath`）在类型层面隔离两套删除机制。UI 改成「磁盘数据 / 运行时资源」两板块 + "启动 Docker"按钮。
13. **M9（继续原计划）**：设置页（⌘,）接通此前只有核心、无 UI 的 `UserExclusionList`（受保护路径增删）与 `DeletionMode.dryRun`（全局预览模式）。`AppSettings.shared` 单例统一供清理/Docker 两条链路取排除名单+预览模式。
14. **M10（全面安全审计，数据安全第一）**：自查+独立 subagent 对抗性复核，核心安全边界无实质性缺陷；修复 3 项（VM 磁盘删除时序竞态、符号链接排除项引擎层失效、Docker 运行检测兜底），详见"M10 审计发现"。
15. **M11（项目构建产物清理 Purge）**：新增 `PurgeArtifactRule`（目录名+标志文件门禁，防止"叫 build 的普通文件夹"被误判成构建产物）+ `PurgeScanner`（深度限界、跳过 `.git`、不追踪符号链接、匹配后不递归）+ `PurgeViewModel`/`PurgeView`（复用已审计的 `DeletionEngine`，未引入新删除机制）+ 设置页新增扫描目录管理。12 个新测试，总数 99→111。
16. **M12（应用卸载器 Uninstaller + 安全审计）**：新增 `InstalledApplicationScanner`（扫描 `/Applications`，扫描时即排除受保护应用）+ `ResidualLocationRule`/`ResidualFileScanner`（残留文件按 safe/caution/destructive 三档，纯路径存在性匹配不做模糊匹配）+ `UninstallerViewModel`/`UninstallerView`（复用 `DeletionEngine`，应用本体+残留删除均携带 bundle id 供引擎二次校验）。自查发现并修复一处路径注入隐患（恶意 Info.plist 的 bundle id/显示名可能让残留路径逃逸）。独立审计发现并修复一处 High 级问题：通用"沙盒容器数据"档位对 Docker 的 VM 磁盘（`~/Library/Containers/com.docker.docker`，真机实测 1.8G）缺少 Docker 模块已有的存活检测，已针对性补上。22 个新测试，总数 111→133。
17. **M13（整体 UI/排版优化，参考 Mole 桌面版风格）**：用户明确要求"整体界面和 ui，排版都优化一下"而非继续加新功能。先用 `WebFetch` 调研 Mole 桌面版（mole.fit，独立付费原生 App）的设计语言（minimal 原生 macOS 美学、每工具独立色彩身份、状态页"bento dashboard"、健康色语义绿/橙/红）。新增 `Features/Shared/FeatureVisuals.swift`（图标徽标+大数字统计组件、统一的风险色常量、状态页用量分级配色），给每个侧边栏功能分配身份色并贯穿到页面主按钮，统一了此前分散不一致的风险徽标颜色（Docker 的黄色改橙色），状态页三张仪表卡片加了按用量分级的动态配色。未改动任何业务逻辑/安全代码，纯视觉层改动。
18. **M14（创意布局落地）**：用户看完 M13 后要求"布局可以再改动一下，来点创意的"。先做了一版 HTML mockup 并用本地预览服务器实际渲染验证（过程中发现并修了 mockup 自身的两个缺陷），用 Artifact 展示获得用户认可后再落地到 SwiftUI：`SidebarView` 改成自定义 Button 列表+虚线"小径"连接图标+当前项抬起效果；`FeatureVisuals.swift` 新增 `ArcGauge`（半圆弧形仪表，已选中/共可清理占比）+ `HeroHeaderWash`（身份色晕染）；Clean/Docker/Purge 页头换成弧形仪表盘，Uninstaller 页头换成大号应用图标（语义不同，不强套弧形仪表）；状态页重做成非对称布局，新增 `MetricRing`（完整圆环）+ `MetricTileStyle`（hero/compact），CPU/内存/磁盘中当前使用率最高的一项自动放大成主卡片。
19. **M15（修复"0 值/缺失数据"混淆）**：`CleanViewModel`/`PurgeViewModel`/`DockerViewModel` 新增 `hasScannedOnce`，`StatusViewModel` 新增 `hasSampledOnce`，用于区分"确实扫描/采样出 0"和"根本还没扫描/采样过"两种状态，未扫描时头部显示新增的 `ArcGaugePlaceholder` 或整页"正在采集…"提示，而非误导性的"0 KB"。
20. **M16（系统状态检测准确性）**：真机 `vm_stat`/`netstat` 核实后修正——内存"已用"公式改为 Activity Monitor 口径的 active+wired+compressed（此前的"总量-free_count"在这台机器上偏差约 3.5GB/22%）；网络吞吐排除 utun/awdl/llw/bridge 等虚拟/隧道网卡（真机当时有一个 VPN 隧道在跑，实测证实旧逻辑会把隧道流量和物理网卡叠加导致读数虚高）。
21. **M17（深度扫描 + 收紧默认勾选）**：Clean 新增 iOS 设备支持文件/模拟器缓存/pip/Cargo/Gradle 位置，`CacheGroup` 默认勾选收紧到只有 App缓存/开发工具/浏览器 三组；Docker 新增"未使用自定义网络"清理；Purge 新增 Go/Python tox/Turborepo/Nuxt/Angular/sbt 共 6 条新规则；Uninstaller 的 `ResidualRiskTier.isDefaultSelectable` 收紧为只有 safe 档默认勾选，并新增登录启动项（LaunchAgents）残留扫描。
22. **M18（安全审计 + 全功能测试，数据安全第一）**：用真实但完全隔离的 `jingshan-selftest-*` 前缀 Docker 容器/镜像/卷/网络验证了 Docker 模块的真实 CLI 行为（不只是 Fake 测试），全程验证不影响真机既有的业务镜像；独立审计对 M14-M17 做了复核，发现 1 项需要处理的评级不一致（Docker 网络清理，已降级处理）+ 补齐了新 Purge 规则的端到端测试，其余复查项目均确认无实质缺陷。详见下方"M18 安全审计发现"与"Docker 模块设计要点"补充说明。
23. **M19（用户要求"能不能把这个项目输出成能用 homebrew 安装的形式"）**：`MARKETING_VERSION` 从 `0.1.0` 提到 `0.7.0`（对齐已交付的实际功能水平）；写了 README.md；用 `gh repo create` 新建了公开仓库 `https://github.com/Ks-Ht/jingshan` 并推送全部代码；`ditto -c -k --sequesterRsrc --keepParent` 打包 Release 构建产物成 `Jingshan-0.7.0.zip`，`gh release create v0.7.0` 发布；写了 `Casks/jingshan.rb`（内嵌在主仓库里的 Cask，不是独立的 `homebrew-jingshan` 仓库，通过 `brew tap ks-ht/jingshan https://github.com/Ks-Ht/jingshan` 这种显式 URL 形式挂载）。实测走完整安装流程时发现两处问题并修正：`brew install --cask --no-quarantine` 报错——这台机器的 Homebrew 版本（6.0.8）根本没有 `--no-quarantine` 这个参数（`brew install --cask --help` 核实过），README 和 Cask 最初都写错了；改为给 Cask 加 `postflight` 块，安装后自动对 `净山.app` 跑 `xattr -cr`，实测确认这样普通用户 `brew install --cask jingshan` 全程不需要任何手动步骤就能正常打开 App。详见下方"M19 Homebrew 分发设计要点"。

**当前完整功能**：缓存/日志/浏览器缓存/开发工具缓存（含 iOS 设备支持/模拟器/pip/Cargo/Gradle）/废纸篓清理（分组展示→勾选→确认→Trash/永久删除→日志，默认只勾选 App缓存/开发工具/浏览器三组）、Docker 专项清理（宿主 VM 磁盘/日志/缓存 + 运行时容器/镜像/构建缓存/数据卷/未使用网络，Docker 停止时也能清宿主数据）、项目构建产物清理（覆盖 Node/Rust/Java/Scala/Swift/Python/Go/Gradle/CocoaPods/Turborepo/Nuxt/Angular，标志文件门禁防误判）、应用卸载器（应用本体+多处残留文件含登录启动项，风险分级+确认门槛，只有安全档默认勾选）、实时 CPU/内存/磁盘/网络监控（口径已按真机数据校正）、设置页（受保护路径 + 预览模式 + 构建产物扫描目录）。磁盘分析、系统优化仍不在范围内（后续迭代）。

### Mole 架构要点（供参考，净山不复用其代码，只借鉴安全设计哲学）
路径校验（绝对路径/禁止穿越/禁止控制字符/解析符号链接后再校验/关键路径黑名单）、受保护应用/路径名单（数据与逻辑分离）、统一删除入口（Trash/永久两种模式+操作日志）、全局 dry-run、用户白名单。GPL-3.0 协议，净山独立 Swift 实现。

## 项目结构
```
cleanmac/
├── project.yml                  # xcodegen 工程描述，唯一需要手改的工程配置来源
├── Jingshan.xcodeproj/          # xcodegen generate 派生产物，已 gitignore
├── App/                         # App 入口、entitlements（无沙盒）、Assets.xcassets（含真实图标）、
│                                # AppSettings（排除名单+预览模式的共享单例）
├── Features/
│   ├── Shared/                  # RootView/SidebarView/TriStateCheckbox（清理+Docker 共用）
│   ├── Clean/                   # CleanView/CleanViewModel/CleanGroupSectionView/
│   │                            # ClassifiedItemRow/CleanConfirmationSheet
│   ├── Docker/                  # DockerView/DockerViewModel/DockerItemRow/DockerConfirmationSheet
│   ├── Purge/                   # PurgeView/PurgeViewModel/PurgeItemRow（构建产物清理，复用 CleanConfirmationSheet）
│   ├── Uninstaller/             # UninstallerView/UninstallerViewModel/UninstallerAppRow/
│   │                            # ResidualCandidateRow/UninstallerConfirmationSheet
│   ├── Status/                  # StatusView/StatusViewModel/Widgets/(四张仪表卡片)
│   └── Settings/                # SettingsView（⌘, 偏好设置：预览模式 + 受保护路径 + 构建产物扫描目录）
├── Permissions/                 # FullDiskAccessChecker/PermissionOnboardingView
└── JingshanCore/                # 本地 Swift Package，与 UI 完全解耦，可独立 swift test
    └── Sources/JingshanCore/
        ├── Safety/               # PathValidator/CriticalPathDenylist/ProtectedAppAllowlist/
        │                         # UserExclusionList/ProtectionEvaluator/DeletionEngine/
        │                         # DeletionMode/DeletionOutcome/DeletionError/OperationLogger/TrashMoving/
        │                         # RunningApplicationChecking
        ├── Scanning/             # ScanTypes/ScanningSupport/CategoryScanning/
        │                         # UserCacheScanner/BrowserCacheScanner/UserLogScanner/
        │                         # TrashScanner/DevToolCacheScanner/ScanCoordinator
        ├── Classification/       # CacheGroup/AppCacheCatalog/CacheItemClassifier
        ├── Metrics/              # SystemSnapshot/CPUMonitor/MemoryMonitor/DiskMonitor/
        │                         # NetworkMonitor/SystemMetricsSampler
        ├── Docker/               # DockerCommandRunning(+DockerCLI)/DockerAvailability/
        │                         # DockerResource(Item/RiskLevel/Kind/RemovalMethod)/
        │                         # DockerResourceScanner/DockerHostDataScanner/
        │                         # DockerCleanupEngine/DockerOperationLogger/DockerSizeParsing
        ├── Purge/                # PurgeArtifactRule/PurgeCandidate/PurgeScanner
        ├── Uninstaller/          # InstalledApplication/InstalledApplicationScanner/
        │                         # ResidualLocationRule/ResidualCandidate/ResidualFileScanner
        ├── Support/              # FileSizeCalculator/ByteFormatter
        └── Resources/            # CriticalPathDenylist.json/ProtectedAppAllowlist.json/
        │                         # AppCacheCatalog.json
        + Tests/JingshanCoreTests/ # 145 个测试，全部通过
```
（早期阶段文件清单见 git 历史/本文件更早版本，此处不重复列出每个文件。）

## Docker 模块设计要点（M7 初版 + M8 增强，务必读懂再改）
- **两套删除机制，类型层面隔离，永不混用**：`DockerRemovalMethod` 枚举——`.dockerCommand([String])` 走 `docker` CLI 子进程（daemon 侧的容器/镜像/构建缓存/卷）；`.filesystemPath(String)` 走已审计的 `DeletionEngine`（宿主侧真实文件：VM 磁盘/日志/应用缓存）。`.filesystemPath` **永远只携带真实 macOS 路径**（`DockerHostDataScanner` 产出、存在性校验过），绝不是 Docker 卷的 `Mountpoint` 这种虚拟机内部路径。这是整个模块最重要的安全不变量，独立审计已确认无处违反。
- **为什么宿主侧扫描很关键（M8 的核心）**：macOS 上 Docker Desktop 把所有镜像/容器/卷/构建缓存都放在一个 Linux 虚拟机的磁盘镜像文件里（`Data/vms/0/data/Docker.raw`，本机实测 1.6G，重度用户可达几十 GB）。daemon 关闭时**没法**从主机侧精细删单个镜像（数据在虚拟机磁盘内部，硬拆会损坏整个数据存储——那才是最不安全的）。所以宿主侧只做两类：回收整个 VM 磁盘（相当于 Docker 恢复出厂，destructive+默认不勾选+走回收站可恢复+仅 Docker Desktop 退出时可回收+删除时二次校验 daemon 不可达）、清日志/应用缓存（safe）。**故意完全不碰 `~/.docker`**（里面混着 config.json 凭据、daemon.json、contexts 上下文定义，删了会掉登录态/上下文）。
- **精细删（需 daemon 运行）**：容器（运行中 destructive、已停止 caution）、悬空镜像（safe）、**未使用的已打标签镜像**（caution+默认不勾选，`docker rmi <repo:tag>` 不加 `-f`，Docker 自身作为权威兜底拒删在用镜像）、构建缓存（`docker builder prune -f`，故意不加 `-a`）、悬空数据卷（destructive）。`docker ps -a -s`（`-s` 才有容器大小）。
- **删除顺序**：`removalPriority` 强制容器→构建缓存→镜像→卷→日志→缓存→VM 磁盘（最后）。容器先于镜像，避免"镜像被停止容器占用而删不掉"。
- **无 shell 注入**：`DockerCLI.run` 一律用 `Process.arguments` 数组传参，不拼 shell 字符串。
- **未使用自定义网络清理（M17 新增，M18 审计后调整过评级，之后又补做了真机验证）**：`scanUnusedNetworks()` 用 `docker network ls --filter type=custom` 探测是否存在自定义网络，做成单一聚合项（像构建缓存一样，不逐个枚举），执行 `docker network prune -f`。**评级是 caution，默认不勾选**——最初实现时评为 safe+默认勾选，独立审计指出"当前未被使用"这个判断本身有时效性（`docker compose stop` 而非 `down` 的项目，其网络会短暂处于这个状态但用户并不想清理），跟文件里另一处"未使用标签镜像"评为 caution 的理由是同一类风险，不该给更宽松的等级，因此改成了 caution+默认不勾选。**这一评级后续已经用真机 Docker 实测确认**：分别测试了"容器 create 时指定 `--network` 但从未 start"和"容器尝试 start 但失败"两种非运行态场景，`docker network prune -f` 在两种情况下都直接把网络删除了，没有因为存在容器引用（哪怕是非运行态）而保护网络——证实了 `network prune` 的"是否在用"判断只看当前正在运行的容器，`docker compose stop` 场景下网络被误清理的风险是真实存在的机制问题，caution+默认不勾选是已验证正确的评级，不是保守猜测。

## Purge 模块设计要点（M11，务必读懂再改）
- **核心风险不是"删除越权"而是"扫描误判"**：Purge 复用已经过 M1/M7/M10 三轮审计的 `DeletionEngine`（黑名单/白名单/Trash 路由/日志一套不少），没有引入新的删除机制。真正的风险点在于扫描阶段——如果只按目录名匹配（比如看到叫"build"的文件夹就当构建产物），会有大量假阳性，可能把用户自己命名为"build"/"target"的重要项目目录当成垃圾展示出来诱导误删。
- **标志文件门禁（marker gating）是这个模块唯一的安全设计**：`PurgeArtifactRule.requiredSiblingMarkers`——只有同级目录里存在对应生态的项目标志文件（如 `node_modules` 要求同级有 `package.json`，`target` 要求同级有 `Cargo.toml` 或 `pom.xml`）才判定为构建产物；没有标志文件的同名目录一律跳过，不展示、不可选、不会被删除。`__pycache__` 是例外（不需要标志文件，因为这个名字本身就是 Python 解释器专用、不会被用户自己拿来命名项目目录）。
- **不追踪符号链接、命中后不再递归**：`PurgeScanner.walk` 在决定是否进入子目录前，先用 `destinationOfSymbolicLink` 判断是否是符号链接，是则跳过——防止软链形成环形导致扫描挂起，也防止软链把扫描范围带出用户预期的项目目录之外。一旦某个目录命中规则（如找到了 `node_modules`），不再往它内部递归（构建产物内部不会再藏着别的独立项目）。
- **最近修改的候选默认不勾选**：`isRecentlyModified`（默认 7 天内）标记的项目，`PurgeViewModel.startScan` 里默认不放进 `selectedIDs`——避免用户刚跑完 `npm install` 还没构建完就被清理工具清空。UI 上用橙色"最近修改"徽标提示。
- **扫描目录默认范围有意收窄**：`PurgeScanner.defaultRoots` 只探测 `~/Projects`/`~/GitHub`/`~/dev` 三个约定俗成的项目根目录（且必须实际存在才纳入），不会全盘扫描整个用户主目录——用户可以在设置页显式添加自定义目录来扩大范围，但默认行为保守。

## Uninstaller 模块设计要点（M12，务必读懂再改）
- **覆盖范围是当前最广的删除面**：Clean/Docker/Purge 都局限在若干个已知安全的目录下（缓存/日志/Docker 数据/项目构建产物），Uninstaller 则要处理"任意已安装的第三方应用"，天然风险面更大。设计上分两条防线：(1) 扫描阶段就用 `ProtectedAppAllowlist` 排除受保护应用（`com.apple.*`、净山自身），不给用户展示可以卸载它们的入口；(2) 真正删除时，应用本体和每一条残留都携带 `associatedBundleIdentifier` 交给 `DeletionEngine`，由它在实际执行删除的那一刻重新核实保护/运行状态——两层防线独立生效，任何一层漏判都有另一层兜底。
- **残留文件匹配只做"精确路径是否存在"，绝不模糊匹配**：`ResidualLocationRule.expectedPath` 用应用的 bundle id 或显示名拼出一个确定的路径模板（如 `Library/Caches/<bundle id>`），`ResidualFileScanner` 只检查这个确定路径是否存在，不做前缀/包含/相似度匹配。这保证了不会把 A 应用的残留误判成 B 应用的（哪怕两者 bundle id 相似，如 `com.example.app` 和 `com.example.app.helper`）。
- **风险分三档（safe/caution/destructive，沿用 Docker 模块的词汇保持全 App 一致）**：缓存/WebKit数据/网络缓存/窗口状态/日志归 safe（默认勾选，可安全删除）；偏好设置/支持文件归 caution（默认勾选，但说明"删除后需要重新配置"）；**沙盒容器数据（`~/Library/Containers/<bundle id>`）归 destructive，默认不勾选**，因为这个目录可能存放应用的实际数据而非仅缓存——这不是理论风险：这台真机上 `~/Library/Containers/com.docker.docker` 实测 1.8G，装的是 Docker 的整个虚拟机磁盘（全部镜像/容器/卷）。
- **Docker 是唯一一个额外加了针对性存活检测的已知案例，不是通用机制**：`UninstallerViewModel.performUninstall` 里，当被卸载的应用 bundle id 是 `com.docker.docker` 时，删除 destructive 档位残留前会额外复用 `DockerAvailability.isDockerDesktopRunning()` + `checkStatus()` 做双重校验（App 未运行且 daemon 不可达才放行），完全比照 Docker 模块自己对 VM 磁盘的保护逻辑。这是独立安全审计发现的问题（通用沙盒容器清理对这一份文件没有 Docker 专属的存活感知，等于给 Docker 模块已经小心把守的门开了一条没人看守的偏门）——修复时刻意没有做成"通用虚拟化工具检测"，只精确针对这一个已验证真实存在风险的 bundle id，避免为假设性的其他工具（Parallels/UTM/VMware 等）过度设计。以后如果用户确实用到其他会在 Containers 里存放大量真实数据的工具，需要再单独评估、单独加类似的针对性检测，而不是假设现有的 destructive 档位勾选框已经足够。
- **Info.plist 里的 bundle id / 显示名不可信任，用作路径前必须过滤**：`InstalledApplicationScanner.readApplication` 直接读取任意 `.app` 的 `Info.plist`，其中的 `CFBundleIdentifier`/`CFBundleDisplayName`/`CFBundleName` 后续会被拼进残留路径模板，而这一步拼接发生在 `PathValidator` 校验之前（`ResidualFileScanner` 只做 `fileExists` 存在性检查）。已加 `isSafeAsPathComponent` 校验（拒绝包含 `/`、等于 `.`/`..`、或为空的值），从源头拒绝而非依赖下游的 `PathValidator` 兜底——虽然下游确实也会拦，但拦住之前 UI 已经会展示出一个具有误导性的默认勾选项，体验和信任度上不可接受。
- **不引入多选批量卸载**：Clean/Docker/Purge 都是"扫一批候选、批量勾选、一次清理"，Uninstaller 刻意做成"选中一个应用、看它的残留、单独确认卸载"——每次操作的爆炸半径天然限制在一个应用范围内，不会出现"一次误操作卸载了 5 个应用"的场景。
- **只有 safe 档默认勾选（M17 收紧）**：`ResidualRiskTier.isDefaultSelectable` 从"除 destructive 外都默认选"改成"只有 safe 默认选"——caution 档（偏好设置、支持文件）虽然 Trash 可恢复，但代表用户可能还想保留的账号登录态/个性化配置，收紧成需要用户自己勾选，不再默认勾了就删。
- **登录启动项扫描（M17 新增，`ResidualFileScanner.scanLaunchAgents`）**：是整个残留扫描器里唯一一处不是"检查单个固定路径"而是"列目录（`~/Library/LaunchAgents`，绝不是需要 root 的 `/Library/LaunchAgents`）+ 前缀匹配"的例外，因为一个应用可能注册好几个 helper agent（`<bundle id>.<后缀>.plist`）而不只是 `<bundle id>.plist`。匹配要求前缀后面紧跟一个字面句点，`com.docker.dockerclient` 不会被当成 `com.docker.docker` 的一部分（已有反例回归测试）；唯一没能完全排除的理论边界是"`com.acme.helper` 恰好是另一个真正独立的第三方应用自己的 bundle id"，但这与 macOS 反向域名命名惯例本身的假设一致（AppCleaner/Pearcleaner 等主流卸载工具都是同样的做法），且爆炸半径仅限于一个 Trash 可恢复、零用户数据的登录项 plist，不涉及对方应用本体或数据。

## 视觉设计系统（M13，务必读懂再改）
- **设计参考来源**：Mole 桌面版（mole.fit，独立付费原生 Mac App，和开源 CLI 是两个不同的产品）。核心原则——minimal 原生 macOS 美学（不堆砌装饰）、每个工具有独立且一致的色彩身份、状态类页面用"bento"风格的磁贴网格、健康/风险状态用绿→橙→红的语义色阶、清理类页面"先看字节数"（大号数字优先于文字描述）。净山没有照抄 Mole 的行星主题包装，而是提炼了同一套设计原则用自己的视觉语言实现。
- **`Features/Shared/FeatureVisuals.swift` 是唯一的视觉常量来源**：`FeatureIconBadge`（页面/卡片图标徽标）、`StatDisplay`（大数字+小字说明组合）、`RiskTint.caution`/`RiskTint.destructive`（风险徽标统一色值，任何模块新增"这个操作有点危险/这个操作很危险"的视觉提示，都应该引用这两个常量，不要再写字面量颜色）、`SystemHealthTint.forUsagePercent`（状态页用量分级配色，<60% 绿/60-85% 橙/>85% 红）。
- **每个 `SidebarItem` 有专属身份色**（`SidebarItem.tint`）：清理=绿、Docker=蓝、构建产物=橙、卸载应用=粉、状态=青。这个颜色同时用在侧边栏图标、该页面头部的 `FeatureIconBadge`、该页面主操作按钮的 `.tint()`——保持"侧边栏图标色 = 页面主色调"的一致性。**卸载应用故意选了粉色而不是红色**，因为红色已经是 `RiskTint.destructive` 专用的"高风险"信号色，如果卸载器的品牌色也用红色，会让用户分不清"这是卸载器"还是"这一项很危险"。以后新增任何页面或调整现有身份色时，注意避开这个冲突。
- **页面头部布局（M13 版本，M14 已升级为弧形仪表盘，见下）**：最初是图标徽标 + 大号字节数统计 + 小字说明；M14 把 Clean/Docker/Purge 三个页面的图标徽标换成了 `ArcGauge`（Uninstaller 保留大图标，语义不同）。主操作按钮突出、次要操作朴素的层级原则不变。
- **M13 这一轮改动是纯视觉层的，没有触碰任何安全/业务逻辑代码**：只改了 Features 目录下的 SwiftUI 视图文件，JingshanCore 完全没有变化。
- **验证方式的真实限制（M13 当时）**：协助开发的终端进程没有 Accessibility/Screen Recording 权限，`screencapture` 实测失败。验证基于"编译通过 + swift test 全绿 + 冒烟无崩溃"，不构成对视觉效果本身的验证。**这个限制在 M14 得到了部分突破，见下方"M14 创意布局设计要点"**。

## M14 创意布局设计要点（务必读懂再改）
- **设计方向来自实际渲染验证过的 mockup，不是凭空想象**：给 `.claude/launch.json` 加了一个 `scratchpad-preview` 配置（本地 `python3 -m http.server` 指向 scratchpad 目录），用 `preview_start`/`preview_screenshot` 等工具真正渲染并肉眼检查了 HTML mockup——这是本会话第一次真正"看到"过设计效果，而不是只凭代码推断。过程中当场发现并修了两个 mockup 缺陷（缺 `charset` 声明导致中文乱码、几个图标和复选框视觉上分不清），验证后才通过 Artifact 展示给用户确认，用户认可后再落地成 SwiftUI 代码。**但 SwiftUI 实现本身仍然没有被真正渲染验证过**——HTML mockup 能看到，原生 App 窗口依然看不到（Accessibility/Screen Recording 权限的限制没变），这一点务必如实告知用户，不能因为 mockup 验证过就误以为最终实现也验证过了。
- **`ArcGauge`（`Features/Shared/FeatureVisuals.swift`）用 `Circle().trim(from:to:)` 而非手算圆弧角度**：`Circle()` 的路径固定从 3 点钟方向顺时针描边，所以 `trim(from:0.5,to:1.0)` 恰好画出"左→上→右"的上半圆弧（拱形），不需要手动计算 SwiftUI 的角度惯例（容易算反导致图形上下颠倒），后续如果要改成其他形状的仪表盘，优先考虑用同样的 `trim` 技巧而不是 `addArc`。
- **状态页"最紧急指标自动放大"是动态计算的，不是固定顺序**：`StatusView.heroMetric` 每次都从当前 CPU/内存/磁盘的实时使用率里取最大值决定谁是主卡片，不存在"CPU 永远最大"这种硬编码假设；只有当选中的主指标本身进入警戒色（非绿色）时才会显示"需要关注"的警示标签，避免每次打开都在吓唬用户。
- **侧边栏放弃了 `List(selection:)`，改用自定义 Button 列表**：为了画虚线小径背景连接图标徽标，牺牲了 SwiftUI 原生 List 的某些内置行为，但每一行仍然是真正的 `Button`（保留 Tab/Space/Return 键盘可达性），不是纯手绘的不可交互视图。

## M19 Homebrew 分发设计要点（务必读懂再改）
- **Cask 而非 Formula**：`brew create` 生态里 GUI macOS App 对应 Cask（管理 `.app` 安装到 `/Applications`），Formula 是给命令行工具/库用的，两者不可混用。
- **内嵌 Cask，不是独立 tap 仓库**：标准做法通常是新建一个专门叫 `homebrew-<name>` 的仓库；这里图省事直接把 `Casks/jingshan.rb` 放进主仓库根目录，用 `brew tap ks-ht/jingshan https://github.com/Ks-Ht/jingshan`（显式给出 URL）挂载，绕开了"tap 名必须匹配仓库名"的默认约定。以后如果 Cask 数量变多或想让别人也能方便地 `brew tap ks-ht/jingshan`（不用手动写 URL），再考虑拆成独立仓库。
- **ad-hoc 签名 + 未公证是已知且用户接受的权衡**：询问过用户"要不要先申请 Developer ID 签名+公证再发布"，用户选择"能接受，反正是我自己用"，明确不追求这一步。这意味着 Gatekeeper 天然会拦截首次启动——`spctl -a -vvvv --type execute` 对这个 App 的判定是 **`rejected`**（真机实测确认，签名信息显示 `flags=0x2(adhoc)`、`TeamIdentifier=not set`），这是 ad-hoc 签名的必然结果，不是 bug。
- **`--no-quarantine` 不是真实存在的 brew 参数（这台机器上，6.0.8 版本）**：最初 README/Cask 都写了"`brew install --cask --no-quarantine`"，实测直接报 `Error: invalid option: --no-quarantine`，`brew install --cask --help` 核实过这台机器安装的版本压根没有这个 flag。**已修正**：改为 Cask 里加 `postflight do system_command "/usr/bin/xattr", args: ["-cr", "#{appdir}/净山.app"] end`，让安装脚本自动清除 quarantine 属性，不需要用户知道任何 brew 参数或手动执行 xattr。这是重新 tap+reinstall 实测验证过的：安装后 `xattr -l` 只剩下无害的 `com.apple.provenance`，没有 `com.apple.quarantine`，`open` 直接可以启动、`log show` 无 error/fault。
- **`spctl -a` 的"rejected"判定和"用户实际能不能双击打开"是两件不完全一样的事，别混淆**：`spctl -a --type execute` 是"这份代码签名本身是否满足 Gatekeeper 公证策略"的独立判定，跟文件有没有 `com.apple.quarantine` 属性无关——即使执行了 `xattr -cr`，重新 `spctl -a` 还是会显示 `rejected`（真机验证过，两种状态下判定都是 rejected）。但决定"Finder 双击时是否弹出拦截对话框"的实际机制是**quarantine 属性本身触发的 LaunchServices 首次启动检查**，一旦这个属性不存在（无论是 `postflight` 自动清掉，还是用户手动 `xattr -cr`），正常 GUI 双击就不会触发那个检查、不会弹拦截对话框，即使 `spctl -a` 单独问起来仍然会说 rejected。caveats 文案措辞上避免了直接断言"清除 quarantine 后 spctl 会说 accepted"这种不准确的说法，只承诺"可以直接双击打开"这个真正对用户有意义的结果。
- **验证方法论上的一个教训**：曾经用这个工具环境里的 `open` 命令（通过自动化 Bash 工具触发，不是真正的 Finder 双击）测试过"quarantine 属性还在的情况下能不能打开"，结果**看起来**启动成功了（有真实 PID）——但这很可能是这个自动化 shell 环境本身缺少完整的交互式 Aqua/WindowServer 会话，导致 Gatekeeper 拦截对话框那一层没有被真正触发，而不是说明 ad-hoc 签名真的能绕过 Gatekeeper。**没有采信这个误导性的初步结果**，而是用更权威的 `spctl -a`（明确说 rejected）和该场景下已被广泛验证的社区共识（quarantine 属性触发首次启动检查，是 Homebrew Cask 生态处理这类未公证 App 的标准套路）来定最终的文档措辞，没有为了图省事而把一次不可靠的自动化测试结果写进面向用户的文档。
- **Release 产物打包用 `ditto` 不是 `zip`**：`ditto -c -k --sequesterRsrc --keepParent 净山.app Jingshan-0.7.0.zip`——Apple 官方推荐的 App bundle 打包方式，比通用 `zip` 命令更能正确保留扩展属性/资源分支，避免解压后签名信息损坏。
- **`sha256`/`url`/`version` 三者要保持同步**：Cask 里 `version "0.7.0"` 驱动 `url` 里的 `#{version}` 插值，指向 GitHub Release 的具体 tag（`v#{version}`）和文件名（`Jingshan-#{version}.zip`）；`sha256` 是发布的 zip 文件的实际摘要（`shasum -a 256`），版本号更新时必须同步重算并更新这个值，否则 `brew install` 会因为校验和不匹配直接拒绝安装（这是 Homebrew 内建的完整性保护，不需要额外自己写校验逻辑）。

## 测试结果
```
cd JingshanCore && swift test
Test run with 145 tests in 27 suites passed.

cd .. && xcodebuild -project Jingshan.xcodeproj -scheme Jingshan -configuration Release build
** BUILD SUCCEEDED **
```
- App 已安装到 `/Applications/净山.app`（ad-hoc 本机签名，`net.kongshan.jingshan`），用 `open /Applications/净山.app` 启动验证：正常运行，`log show` 无 error/fault/crash。
- `SystemMetricsSamplerTests` 直接对真实系统采样做合理性断言（内存总量与 `ProcessInfo` 一致、CPU 核心数与 `ProcessInfo` 一致、二次采样后使用率在 0-100% 范围内、网络吞吐非负）——这类 OS 集成点没有走 mock，直接验证真实系统调用。

**环境要求**：`xcode-select` 已切换到 `/Applications/Xcode.app/Contents/Developer`，`swift build`/`swift test`/`xcodebuild` 均可直接使用，无需 `DEVELOPER_DIR=` 前缀。`xcodegen`（2.45.4）已通过 Homebrew 安装，工程改动后需 `xcodegen generate` 重新生成 `.xcodeproj`（已 gitignore，不进仓库，`project.yml` 才是真源）。

## 当前状态
App 已构建、已安装、已验证可启动无崩溃，六大功能（清理、Docker 清理、构建产物清理、应用卸载、状态监控、设置）均已实现并接入真实系统 API/文件系统/Docker CLI，做过两轮视觉/排版优化（M13 一致性配色 + M14 创意布局），并做过一轮"深度扫描+收紧默认勾选+系统监控口径校正"的功能完善（M15-M17），完成了一轮结合真机 Docker 容器验证的全面安全审计（M18），最后完成了 GitHub 开源 + Homebrew Cask 分发（M19）——项目现在公开在 `https://github.com/Ks-Ht/jingshan`，标签 `v0.7.0` 已发布 Release，任何人（包括用户自己换新机器）都可以用 `brew tap ks-ht/jingshan https://github.com/Ks-Ht/jingshan && brew install --cask jingshan` 一步装好，postflight 自动处理 quarantine，不需要额外手动步骤。**界面点击走查依然没做过**（缺 Accessibility/Screen Recording 权限，`screencapture` 本轮再次实测确认仍不可用），建议用户自己打开 `/Applications/净山.app` 走一遍：清理页扫描→勾选→清理→查看结果（这次分类默认勾选范围收紧了，AI 工具/其他两组不再默认选中，需要的话手动勾）；状态页看实时数据（内存口径这次校正过，数字应该比之前更接近 Activity Monitor；三张卡片里用量最高的会自动变成大卡片）；Docker 页（这台机器 Docker 已恢复停止状态，正好可以验证"宿主磁盘数据"板块，新增的"未使用自定义网络"清理项在运行时资源里，默认不勾选）；构建产物页（新增了 Go/Python/Turborepo/Nuxt/Angular 等生态识别）；卸载应用页（残留文件默认勾选范围也收紧了，只有缓存类默认选中；新增登录启动项扫描，建议先挑一个不重要的小工具类应用试一遍完整流程）；⌘, 打开设置页试预览模式、受保护路径、构建产物扫描目录。

## M18 安全审计发现（本轮，已全部处理）
针对 M14-M17 的全部改动（创意布局落地、0 值显示修复、系统监控口径校正、深度扫描+收紧默认勾选）做了自查+独立 subagent 对抗性复核，并且首次按用户"想办法用容器或沙箱等虚拟数据测试"的明确要求，用真实但完全隔离的 Docker 资源验证了 Docker 模块（而不只是 Fake 测试）。

**Docker 真机验证过程**（务必了解这套方法论，以后验证 Docker 相关改动可以复用）：这台机器当时 Docker 是停止的且有真实业务镜像（`outpost-server` 系列 + `debian`）。启动 Docker Desktop 前先只读核实了这些真实资源的存在，全程只操作 `jingshan-selftest-` 前缀的自建资源。用纯本地 `docker build`（不依赖网络拉镜像，因为期间遇到过一次 registry 连接卡住）搭了一套容器/镜像（含悬空镜像+被占用的标签镜像）/卷/自定义网络，写了一个需要显式环境变量（`JINGSHAN_REAL_DOCKER_SELFTEST=1`）才会运行的临时集成测试文件，用真实的 `DockerCLI`（不是测试用的 Fake）跑生产代码的扫描逻辑，验证完立刻删除了这个临时测试文件。**过程中被 Claude Code 自带的权限分类器正确拦下过一次**——原本还想再验证"真实删除"这一步，但那段测试代码用 `"<none>:<none>"` 做匹配键，对悬空镜像这种系统通用占位符不是唯一标识，分类器判定有风险，拦截是对的；没有尝试绕过，而是放弃了"让测试代码自己做真实删除"的思路，改用人工核对过的精确 ID/名称直接发 `docker` 命令清理测试资源，逐项核对真实环境在测试前后完全一致（7 个真实镜像、无容器无卷无自定义网络），最后把 Docker Desktop 关回原来的停止状态。这个过程还顺带验证了一个真实的正向案例：一个被已停止（非运行）容器引用的镜像，确实不会被"未使用镜像"逻辑误判为可清理——是安全逻辑生效的证据。

**独立审计发现**：
1. **（已处理，且已真机验证确认）Docker"未使用自定义网络"清理的风险评级不一致**：最初实现评为 safe+默认勾选，审计指出这和文件里"未使用标签镜像"（同样因为"当前未被使用"而评为 caution）是同一类风险判断，不该给更宽松的等级——`docker compose stop`（而非 `down`）的项目网络可能被误判为可清理。已改为 caution+默认不勾选。**这一条最初提交时没能及时在真机验证，后续用户要求"继续跑一遍"后补验证了**：Docker Desktop 启动成功后，实测了两种情况——(a) 容器 `create` 时指定了 `--network` 但从未 `start` 过（一直是 `Created` 状态），(b) 容器尝试 `start` 过但因为镜像本身没有可执行的 CMD 而启动失败（同样停在 `Created`）——两种情况下 `docker network prune -f` 都**照样把网络删除了**，没有因为存在（哪怕非运行态的）容器引用而保护网络。这证实了审计的担心是真实存在的机制问题，不只是理论推测：`docker network prune` 的"是否在用"判断只看当前正在运行的容器，不看任何配置引用过该网络但当前不在运行的容器。caution+默认不勾选的评级现在是**已验证确认**，不是保守猜测。
2. **（确认无需改动）LaunchAgents 前缀匹配、pip 去重、tightened-defaults 一致性、`hasScannedOnce` 时序、内存公式溢出风险**——五项重点复查对象逐一验证后均无实质缺陷，独立审计原话"这批改动的作者在编写时已经预判到了审计会问的问题"。
3. **（已处理）测试覆盖缺口**：新增的 `.tox`/`.turbo`/`.nuxt`/`.angular`/`build.sbt` 只有通用机制测试覆盖、缺专项端到端验证，已补齐 `.tox`/`.angular`/`build.sbt` 三个代表性场景的 `PurgeScanner` 测试。

用 `ReportFindings` 正式汇报了全部 5 项。核心结论与历次审计一致：**未发现会导致删错文件、危险项被默认勾选、或绕过确认的实质性缺陷**；本轮唯一真正处理的问题是"评级不一致"而非"校验有漏洞"。

## M12 安全审计发现（已处理）
新增应用卸载器（Uninstaller）是继 Docker 之后覆盖范围最广的删除面（可以删除任意第三方应用本体+多处残留文件），按用户"数据安全在第一位"的标准指令做了自查+独立 subagent 对抗性复核。

**自查阶段**（先于独立审计，自己找出并修复）：`InstalledApplicationScanner.readApplication` 直接读取任意 `.app` 的 Info.plist，其中 `CFBundleIdentifier`/`CFBundleDisplayName`/`CFBundleName` 后续会拼进残留文件路径模板，而这一步发生在 `PathValidator` 校验之前。一个恶意构造的 bundle id（如 `../../../etc`）能让计算出的路径逃逸出预期目录，虽然真正执行删除时 `PathValidator` 的黑名单最终会拦下来，但扫描阶段会先展示出一个具有误导性的默认勾选项。已加 `isSafeAsPathComponent` 校验从源头拒绝（拒绝包含 `/`、等于 `.`/`..`、或为空的值），补了 2 个回归测试。

**独立审计阶段**：派了一个独立 general-purpose subagent 做只读对抗性复核（覆盖受保护应用双层排除、禁止强制覆盖运行中应用、残留匹配是否可能误配到别的应用、路径注入、destructive 档位默认与确认门槛、是否绕过 `DeletionEngine` 单一入口、排除名单与预览模式是否生效、测试覆盖是否只测 happy path）。审计过程中一度因流式连接卡死中断，用 `SendMessage` 恢复了同一个 agent（保留已读过的全部上下文）继续完成剩余检查项，比从零重跑更高效。发现并处理 4 项：
1. **（High，已修复）通用"沙盒容器数据"档位对 Docker 的 VM 磁盘缺少存活检测**：`~/Library/Containers/com.docker.docker`（真机实测 1.8G，装着 Docker 的整个虚拟机磁盘）会被卸载器的通用沙盒容器清理逻辑当成普通残留处理，而 Docker 自己的清理模块对同一份文件有三层保护（扫描时隐藏/删除时二次校验 App 运行状态/二次校验 daemon 可达性）。独立审计原话："这是绕开 Docker 模块已审计门禁、通往同一个危险结果的第二条更弱路径"。已在 `UninstallerViewModel.performUninstall` 中针对 `com.docker.docker` 这一个已知案例，复用 `DockerAvailability.isDockerDesktopRunning()` + `checkStatus()` 做同样的双重校验，命中则跳过而非删除。详见"Uninstaller 模块设计要点"一节。
2. **（Low，已加注释）确认弹窗的选中状态是快照而非实时绑定**：`hasDestructiveSelection`/`selectedCount`/`totalBytes` 在弹窗打开时求值一次，不随后续变化更新。审计确认当前不构成漏洞（SwiftUI 模态弹窗打开时用户物理上无法触达父视图的残留勾选框），但补了代码注释记录这个隐含前提，防止未来重构（例如把残留列表挪进弹窗内部）时悄悄引入 bug。
3. **（确认无需改动）并发重入检查**：`performUninstall`/`selectApp` 的任务取消与状态置位逻辑经追踪确认正确——`isUninstalling` 在唯一的 `await` 点之前就同步置位，`@MainActor` 隔离下不可能被绕过；`selectApp` 切换选择时正确取消旧的残留扫描任务并用 `Task.isCancelled` 防止过期结果覆盖新选择。
4. **（确认无需改动）`FileSizeCalculator`/图标加载崩溃路径检查**：全程使用 `try?`/优雅兜底（`NSWorkspace.icon(forFile:)` 对不存在路径返回通用图标而非抛异常），未发现崩溃路径。

用 `ReportFindings` 正式汇报全部 4 项。核心结论与之前几轮审计一致：**未发现会导致删错文件、危险项被默认勾选、或绕过确认的实质性缺陷**；找到的 1 个 High 问题是"通用机制没有覆盖到一个已知的特殊情况"，而非"安全校验本身有漏洞"——修复方式也刻意保持窄范围（只精确针对 `com.docker.docker` 这一个已验证真实存在风险的 bundle id），没有为假设性的其他虚拟化工具做过度设计。

## M10 安全审计发现（已处理）
自查 + 独立 subagent 对抗性复核，核心安全边界（不删错文件、危险项不默认勾选、Docker VM 磁盘/主机路径隔离、预览与排除真实生效、无 shell 注入）**均确认成立、无实质性缺陷**。修复 3 项：
1. **VM 磁盘删除时序竞态（较重要）**：VM 磁盘只在 Docker Desktop 退出时"提供"，但用户可能扫描后又启动 Docker 再点清理——那样会删除运行中 VM 的磁盘造成损坏。已在 `DockerViewModel.performCleanup` 加删除时二次校验：删 `.diskImage` 前重新确认「App 未运行 **且** daemon 不可达」，否则拒绝该项。
2. **符号链接排除项在引擎层可能失效**：排除名单存的是未解析路径，但 `DeletionEngine` 只拿解析后路径比对，符号链接排除项可能匹配不上。已改为**同时比对原始路径与解析后路径**，并加回归测试。
3. **Docker Desktop 运行检测的 bundle-id 兜底**：`isDockerDesktopRunning()` 只精确匹配 `com.docker.docker`；已通过第 1 条的 daemon 二次校验兜底（App 检测漏报时 daemon 检测仍会拦住 VM 磁盘删除）。

## M7 安全审计发现（Docker 初版时，已全部处理）
按用户要求做的完整审计（自查 + 独立 subagent 对抗性复核），核心安全边界（不删错文件、危险项不默认勾选、Docker 卷路径不碰主机文件系统）**均确认成立、无实质性缺陷**。发现并修复了 9 项问题，均已修复（详见 git diff / 代码注释）：
1. `UserCacheScanner` 默认排除名单漏掉了 `DevToolCacheScanner` 也占用的 `org.swift.swiftpm`/`Homebrew` 两个文件夹名 —— 这两个文件夹在这台真机上真实存在，此前会被同时算进"用户缓存"和"开发工具缓存"两个分组，重复展示、重复计入总大小。已修复：`DevToolCacheScanner` 新增 `topLevelCacheNamesToExcludeFromGenericScan`，`UserCacheScanner` 默认排除名单改为两者的并集，并加了回归测试。
2. `docker ps` 调用漏了 `-s`/`--size` 参数，会导致所有容器的大小字段一直是空的。已加上。
3. 构建缓存清理原本用 `docker builder prune -a -f`，`-a` 会连现有镜像仍在共享的缓存层也一起清掉，比界面上"安全"的措辞和展示的大小更激进。已去掉 `-a`，文案和实现现在完全对得上。
4. 直接读了这台真机的 `~/Library/Caches` 做了逐条核对（而不是凭训练数据猜），发现并修正：Chrome 的三条 `com.google.Chrome*` 目录名匹配规则从未匹配过任何真实文件夹（Chrome 实际用的是 "Google" 父目录，已被 `BrowserCacheScanner` 单独处理）已删除；Docker Desktop 的真实缓存文件夹名是 "Docker Desktop"（不是猜测的 bundle id 形式）已补上；ChatGPT 的真实缓存文件夹名是 "ChatGPTHelper" 已补上。
5. "腾讯柠檬"（`com.tencent.Lemon`，一个 Tencent 工具箱应用）被错误归到"通信工具"分组——这个分组默认不勾选且文案说"可能包含未备份的聊天图片/视频"，对一个工具箱应用完全文不对题。已改到"其他"分组。
6. 独立审计 agent 又核实出：`Sequel Ace` 的 bundle id 写错了（`com.eggerapps.Sequel-Ace` 应为 `com.sequel-ace.sequel-ace`），影响很小（只影响分类展示，不影响删除安全）。已修正。
7. 独立审计 agent 指出 `CleanViewModel`/`DockerViewModel` 的扫描和清理动作之间没有互斥保护（虽然 `@MainActor` 下不构成真正的数据竞争，但可能有 UI 状态混乱）。已加 `guard !isScanning, !isCleaning` 互斥保护。
8. （结构性提醒，非当前 bug）跨分类去重目前完全靠人工维护的排除名单集合保证正确——现在的集合是完整且正确的，但**以后新增任何 `DevToolCacheScanner`/`BrowserCacheScanner` 里指向 `~/Library/Caches` 子目录的位置时，必须同步加进对应的 `topLevelCacheNamesToExcludeFromGenericScan`**，否则第 1 条的 bug 会以新的文件夹名字重现。

## 风险/注意事项（按重要性排序）
1. **删除必须用原始路径而非解析后路径**（M1 遗留，`DeletionEngine` 内部实现细节，修改前务必读代码注释）——否则对指向合法位置的符号链接执行删除会误删目标内容。
2. **`CriticalPathDenylist` 对 `/private` 整体拒绝**（简化设计，非 Mole 的精细两段式），因此任何未来的 fixture/测试/功能都不要假设可以操作系统临时目录（`NSTemporaryDirectory()` 解析后落在 `/private/var/folders/...`，会被拒绝）。
3. **废纸篓分类是特殊路径**：`TrashScanner` 返回代表整个 `~/.Trash` 的单一聚合项，UI 层专门用"清空废纸篓"按钮处理（永久删除其内容，而不是把 `~/.Trash` 本身移进回收站——那样语义不通）。以后如果重构清理流程，不要把废纸篓并入通用的多选清理路径。
4. **`BrowserCacheScanner`/`DevToolCacheScanner` 与 `UserCacheScanner` 用共享排除名单去重**（各自的 `topLevelCacheNamesToExcludeFromGenericScan`，`UserCacheScanner` 取并集）。新增任何指向 `~/Library/Caches` 子目录的已知浏览器/开发工具位置时，两处都要同步，否则会重复展示+重复计入大小（M7 审计踩过一次）。
4b. **Docker 模块的删除机制隔离是硬不变量**：`.filesystemPath` 只能携带真实 macOS 路径（宿主 Docker 数据），永远不能是 Docker 卷 `Mountpoint` / 容器 ID / 镜像 ID 这类虚拟机内部标识；daemon 侧资源一律走 `.dockerCommand`。VM 磁盘删除必须保持"仅 Docker 退出时可回收 + 删除时二次校验 daemon 不可达"这两道门。改 Docker 模块前务必读 `Docker 模块设计要点` 那一节。
5. **Swift 6 严格并发的两个坑**（已踩过，别再踩）：(a) `NSEnumerator` 的 fast-enumeration 语法在 async 函数里不可用，要先 `.allObjects as? [String]` 落地成数组；(b) 把 actor 持有的非 Sendable 类型（如 `FileManager`）传给 nonisolated 协议方法会触发 "sending risks causing data races"，本项目的解法是让调用方（各 Scanner/Monitor）内部直接用 `.default`，不做跨 actor 边界的依赖注入。
6. **公开的值类型必须写显式 `public init`**：Swift 不会为 `public struct` 自动合成 `public` 的 memberwise 初始化器（合成的默认是 internal），M4 开发中因此在 App 模块的 Preview 代码里踩过一次编译错误（`Metrics/SystemSnapshot.swift` 的四个 snapshot 类型）。以后在 JingshanCore 里新增需要跨模块构造的 `public struct`，记得手写 `public init`。
7. **App 图标/构建产物不是真正的商业分发级签名**：`CODE_SIGN_IDENTITY=-`（ad-hoc 本机签名），没有 Developer ID，没有公证。这对"个人在自己 Mac 上用"完全没问题（已验证可正常安装运行），但如果以后想分享给别人或上架，必须：(a) 用户自己的 Apple Developer Program 账号（$99/年，我这边没有也无法代为注册），(b) 在 Xcode 里配置 Team + Developer ID Application 证书，(c) `notarytool` 提交公证。这一步只有账号持有人自己能做。
8. **`AppCacheCatalog.json` 是尽力而为的最佳猜测清单，不是权威数据源**：部分条目（如 Cursor 的 `com.todesktop.*`、Termius 的 bundle id）是根据公开印象/常见命名规律写的，不保证每个版本都精确匹配；不匹配也不会出问题（自动兜底到"Apple 系统组件"或"其他"分类），只是那一项少一个友好名字。以后发现某个常见 App 没被正确识别，直接在这个 JSON 里加一条 `{namePattern, displayName, group}` 即可，不用改代码。
9. **图标是我用 Core Graphics 程序化画的**（三层水墨山峦剪影 + 新月），不是设计师作品，风格偏极简；如果用户不喜欢，`generate_icon.swift`（在会话 scratchpad，不在仓库里，需要的话我可以重新放到仓库某处再改）改几个坐标/颜色重新跑一遍即可。
10. **卸载器的"沙盒容器数据"存活检测目前只覆盖 Docker 这一个已验证案例**：`UninstallerViewModel.performUninstall` 里只对 `com.docker.docker` 做了 `DockerAvailability` 二次校验（详见"Uninstaller 模块设计要点"）。如果以后用户安装了其他会在 `~/Library/Containers` 里存放大量真实数据的虚拟化/容器类工具（Parallels、UTM、VMware Fusion 等），卸载那些工具时，通用的 destructive 档位默认不勾选+确认弹窗二次勾选仍然生效（不会误删），但不会有针对该工具"是否仍在运行/是否有活动虚拟机"的专属存活检测——这是已知的、经过独立审计确认可接受的范围限制，不是遗漏。以后如果用户明确要卸载某个虚拟化工具，需要重新评估是否要加类似 Docker 的针对性检测。
11. ~~Docker"未使用自定义网络"清理未在真机上验证过"停止容器是否仍保护网络"这个细节~~ **已在真机验证确认**（M17 新增，M18 审计后降级为 caution+默认不勾选；后续补验证证实了 `docker network prune` 确实不会因为存在非运行态容器引用而保护网络，caution+默认不勾选是正确评级，不需要再放宽）。详见"Docker 模块设计要点"最后一条 和 "M18 安全审计发现"。
12. **ad-hoc 签名 + 未公证是长期存在、用户已知情接受的分发限制**（M19）：`spctl -a` 对这个 App 的判定固定是 `rejected`，Cask 的 `postflight` 只是自动清除 quarantine 属性从而让 Finder 双击不触发拦截对话框，并不能让签名本身变得"受信任"。如果以后要分享给用户之外的其他人，或者想要更顺滑的体验（没有任何 Gatekeeper 相关的疑虑），仍然需要走风险清单第 7 条说的 Developer ID + 公证流程——这是账号持有人（用户自己）才能决定要不要付费（$99/年）去做的事，协助开发的一方无法代劳。
13. **`Casks/jingshan.rb` 里的 `sha256`/`version`/`url` 三者必须手动保持同步**：以后每次发新版本（改 `project.yml` 的 `MARKETING_VERSION` + 重新构建 + 打包 + 发 Release），必须同步更新 Cask 里这三个字段（尤其是 `sha256`，用 `shasum -a 256` 重新计算新 zip 的摘要），否则用户 `brew install`/`brew upgrade` 会因校验和不匹配直接失败。目前没有自动化这个流程（没有 CI/CD 脚本），是纯手动步骤，容易忘记。

## 已知限制
- 我这边跑 Claude Code 的终端进程没有"屏幕录制"和"辅助功能"权限，所以从 M2 到 M14（创意布局落地）都无法对**原生 App 本身**截图或做 UI 自动化走查，每次都用 `screencapture` 实测确认过仍然不可用（"could not create image from display"），不是偷懒没试。只能靠：编译通过 + 单元测试 + 直接运行可执行文件观察崩溃/日志。**M14 在"设计方向确认"这一步有所突破**——通过本地起 HTTP 服务器预览 HTML mockup、真正截图检查过（详见"M14 创意布局设计要点"），但这只验证了设计方向，最终的 SwiftUI 实现本身仍然没有被截图验证过。**建议用户自己点开 App 走一遍完整流程**，如果发现界面问题告诉我，我可以针对性修。
- CPU 的计算方式没有变过，是标准的 `host_processor_info` tick 差值法，比较可信。内存"已用"口径 M16 已从"总量-free_count"改成 Activity Monitor 口径的"active+wired+compressed"，用真机 `vm_stat` 核对过更准确，但仍是一种近似（不区分 App/Wired/Compressed 分别多少，只给一个合计"已用"）。网络吞吐 M16 已排除常见虚拟/隧道网卡（VPN/AirDrop/Thunderbolt Bridge 等），但仍是"所有物理网卡求和"，不是"识别默认路由网卡"，多网卡同时活动时（如 Wi-Fi+有线同时连接）仍会偏高；且如果用户真的用 Thunerbolt Bridge（`bridge0`）作为主力网络连接（罕见），会被误判为虚拟网卡而漏统计。

## 下一步该做什么（如果继续迭代）
0. **（M19 新增）如果要发新版本**：改 `project.yml` 的 `MARKETING_VERSION` → Release 构建 → `ditto -c -k --sequesterRsrc --keepParent 净山.app Jingshan-<version>.zip` → `shasum -a 256` 算新摘要 → `gh release create v<version> <zip>` → 更新 `Casks/jingshan.rb` 的 `version`/`sha256`（`url` 会随 `#{version}` 插值自动跟着变，不用手改）→ commit+push → 本地 `brew untap`/`brew tap` 刷新缓存后 `brew upgrade --cask jingshan` 冒烟验证一遍。
1. **用户自己走查一遍界面，重点看 M14 创意布局的实际效果**（路径式侧边栏、弧形仪表盘头部、状态页动态放大的主卡片）是否符合预期——SwiftUI 实现本身没有被截图验证过，需要用户的眼睛来确认。同时验证 M17 收紧的默认勾选范围（清理页/卸载应用页现在默认选中的项变少了）是否符合预期，以及 M16 校正后的内存/网络数字是否更准了。
2. Docker 网络清理的风险评级需要真机验证补完（见风险清单第 11 条）。
3. Uninstaller 可扩展方向：`~/Library/Group Containers`（v1 故意跳过，group id 与 bundle id 不是简单对应关系，匹配可靠性不够）；如果用户确实要卸载 Parallels/UTM/VMware 等其他虚拟化工具，需要重新评估是否要为它们也加类似 Docker 的针对性存活检测（见风险清单第 10 条）。
4. 视觉/体验的更大改动（M13/M14 都故意没做）：换图标、Status 历史曲线（sparkline，Mole 桌面版有"60 秒走势图"）、菜单栏 MenuBarExtra（架构一直预留）。
5. 正式分发：申请 Apple Developer Program，配置签名+公证，打 DMG。
6. 其余后续功能（明确排除在当前范围外）：磁盘空间分析（Mole 桌面版叫"Analyze"，treemap 可视化）、系统优化维护（需要 sudo，安全模型要重新设计）、安装包清理。

## 下一位 Agent 如何接手
1. 先读本文件 + `docs/PROGRESS.md` + `docs/NEXT_STEPS.md`。
2. `cd JingshanCore && swift test` 确认 145 个测试全绿。
3. 改了 App/Features/Permissions 下的文件结构（加/删文件）后记得 `xcodegen generate` 重新生成工程，再 `xcodebuild -project Jingshan.xcodeproj -scheme Jingshan -configuration Debug build` 验证。
4. Release 构建 + 安装：`xcodebuild -project Jingshan.xcodeproj -scheme Jingshan -configuration Release build`，产物在 `~/Library/Developer/Xcode/DerivedData/Jingshan-*/Build/Products/Release/净山.app`，`cp -R` 到 `/Applications/` 替换旧版本即可（本机日常验证走这条路径，不必每次都过 Homebrew）。
5. 如果要做界面相关改动，构建后至少用 `open /Applications/净山.app` 跑一下 + 检查 `log show --predicate 'process == "净山"'` 有没有 error/fault；如果拿到了 Screen Recording 权限，可以用 `screencapture` 截图辅助验证。
6. **仓库已公开在 `https://github.com/Ks-Ht/jingshan`，且已有 Homebrew Cask（`Casks/jingshan.rb`）**——发新版本流程见上面"下一步该做什么"第 0 条；改动 `Casks/jingshan.rb` 后先本地 `brew style ks-ht/jingshan/jingshan`（不是直接对仓库里的文件路径跑，`brew style` 要求文件在已识别的 tap 里，要么先 push 再 `brew untap`/`brew tap` 刷新，要么直接改 `/opt/homebrew/Library/Taps/ks-ht/homebrew-jingshan/Casks/jingshan.rb` 里的本地副本测试语法后再同步改回仓库文件）确认没有 rubocop 报错。
