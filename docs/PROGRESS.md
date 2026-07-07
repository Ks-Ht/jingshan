# PROGRESS

## 项目目标
参考 https://github.com/tw93/mole（Mole）的架构思路（尤其是安全清理设计），为用户开发一款 Swift 原生 Mac 清理/监控 App，命名为「净山」(Jingshan)。

## 当前阶段
**v0.7 可用产品已交付**：M1-M6 完成；M7 新增 Docker 专项清理（含安全审计，修复 9 项）；M8 大幅增强 Docker（宿主侧数据扫描，Docker 停止时也能清；未使用镜像清理；VM 磁盘回收）；M9 补齐原计划的设置页（受保护路径管理 + 预览模式）；M10 再次全面安全审计（数据安全第一，修复 3 项，含一个真实的删除时序竞态）；M11 新增项目构建产物清理 Purge；M12 新增应用卸载器 Uninstaller（含安全审计，修复 1 个 High 级跨模块风险）；M13 全局视觉一致性优化；M14 应用户要求做了更大胆的创意布局（路径式侧边栏、弧形仪表盘、状态页动态非对称布局），过程中首次用本地预览服务器真正渲染验证了设计 mockup；M15 修复"0 值与缺失数据混淆"问题；M16 校正系统状态监控口径（内存/网络，均用真机数据核实过偏差）；M17 深度扩展四个清理模块的扫描范围同时收紧默认勾选；M18 全面安全审计+全功能测试，首次用真实但完全隔离的 Docker 容器/镜像/卷/网络验证 Docker 模块（而非只用 Fake），全程不影响真机已有数据。App 已安装在 `/Applications/净山.app` 并验证可正常运行，145 个单元测试全部通过。

## 已完成
- 调研 tw93/mole 架构，确认关键决策：Swift 原生 App、GUI、MVP=垃圾清理+状态监控、名称=净山、仅 macOS。
- EnterPlanMode 产出详细实现方案并获批准。
- 系统级修复：`xcode-select` 切换到完整 Xcode 26.6。
- **M1**：`JingshanCore` 核心安全引擎（PathValidator/CriticalPathDenylist/ProtectedAppAllowlist/UserExclusionList/DeletionEngine/OperationLogger/TrashMoving）。
- **M2**：xcodegen 生成非沙盒 App 工程；Scanning 模块（5 类扫描器）；只读清理列表 UI；完全磁盘访问权限引导。
- **M3**：`ProtectionEvaluator` 统一受保护判定；`CleanViewModel` 选择/清理执行；勾选/预览/二次确认 UI；废纸篓单独清空动作；操作全部经 `DeletionEngine` 落日志。
- **M4**：Metrics 模块（CPU/内存/磁盘/网络，Mach/BSD 底层调用）；`StatusViewModel` 实时采样；四张仪表卡片 UI。
- **M5（部分）**：程序化生成应用图标；Release 构建；安装到 `/Applications/净山.app` 并验证运行。
- **M6**：用户看实机截图反馈"清理列表全是原始 bundle id 看不懂"，对照 Mole Mac 客户端截图，新增 `CacheGroup`/`AppCacheCatalog`/`CacheItemClassifier` 分类系统，清理列表改为可折叠分组（App缓存/开发工具/AI工具/浏览器/通信工具/其他/废纸篓），常见 App 显示友好名称，通信工具分组默认不勾选保护聊天记录/媒体。
- **M7**：新增 Docker 专项清理模块（容器/悬空镜像/构建缓存/悬空数据卷，全程只用 `docker` CLI 子进程操作，绝不碰主机文件系统），风险分级+备注，危险项默认不勾选。之后做了完整安全审计（自查+独立 subagent 对抗性复核），发现并修复 9 项问题。
- **M8（用户要求"Docker 更有强度、不需要 Docker 运行"）**：新增宿主侧数据扫描（`DockerHostDataScanner`）——Docker 停止时也能扫描/回收 Docker Desktop 在硬盘上的真实数据（VM 虚拟磁盘 `Docker.raw` 是大头、日志、应用缓存），走已审计的 `DeletionEngine`（回收站可恢复）；VM 磁盘为 destructive、默认不勾选、仅在 Docker Desktop 退出时可回收。daemon 运行时新增"未使用镜像"清理（不止悬空镜像，用 `docker rmi` 不加 `-f` 让 Docker 自身兜底拒删在用镜像）。UI 改成「磁盘数据 / 运行时资源」两大板块，Docker 关闭时也能用，并提供"启动 Docker"按钮。引入 `DockerRemovalMethod`（命令 vs 文件路径）在类型层面隔离两套删除机制。
- **M9（继续原计划）**：补齐设置页（⌘,）——接通此前只有核心、没有 UI 的 `UserExclusionList`（受保护路径增删，永不清理）与 `DeletionMode.dryRun`（全局预览模式，开启后清理与 Docker 操作都只预览不实删）。清理与 Docker 两条链路都改为经 `AppSettings.shared` 取排除名单+预览模式。
- **M10（全面安全审计，数据安全第一）**：自查+独立 subagent 对抗性复核，确认核心安全边界（不删错文件、危险项不默认勾选、Docker VM 磁盘/主机路径隔离、预览与排除真实生效）无实质性缺陷；修复 3 项：(1) VM 磁盘删除时序竞态（扫描时 Docker 已退出但删除前又启动会损坏运行中 VM）——加了删除时二次校验（App 未运行且 daemon 不可达才允许）；(2) 符号链接排除项在引擎层可能失效——引擎改为同时比对原始路径与解析后路径；(3) Docker Desktop 运行检测的 bundle-id 兜底。
- **M11（项目构建产物清理 Purge，对应 `mo purge`）**：新增 `PurgeArtifactRule`（目录名+标志文件门禁）+ `PurgeScanner`（深度限界/跳过 .git/不追踪符号链接/命中不递归）扫描 node_modules/target/.build/dist/venv/__pycache__ 等常见构建产物；`PurgeViewModel`/`PurgeView` 复用已审计的 `DeletionEngine`，未引入新删除机制；设置页新增扫描目录管理。核心风险是扫描误判（已用标志文件门禁+专项测试覆盖），非删除越权，故未安排独立的第四轮全量审计。
- **M12（应用卸载器 Uninstaller，对应 `mo uninstall`）**：新增 `InstalledApplicationScanner`（扫描 `/Applications`，排除受保护应用）+ `ResidualLocationRule`/`ResidualFileScanner`（残留文件按 safe/caution/destructive 三档，纯路径存在性匹配）+ `UninstallerViewModel`/`UninstallerView`（复用 `DeletionEngine`）。自查发现并修复一处路径注入隐患（恶意 Info.plist 的 bundle id/显示名可能让残留路径逃逸）。这是继 Docker 之后覆盖范围最广的删除面，按惯例做了独立安全审计，发现并修复 1 项 High 级问题：通用的"沙盒容器数据"清理对 Docker 的 VM 磁盘（真机实测 1.8G）缺少 Docker 模块已有的存活检测，已针对性补上（不做成通用虚拟化工具检测，只精确覆盖这一个已验证案例）。
- **M13（整体 UI/排版优化，参考 Mole 桌面版风格）**：用户主动选择"先优化界面"而非继续做磁盘分析/系统优化维护两个更大的新功能。用 `WebFetch` 调研 Mole 桌面版（mole.fit）设计语言（minimal 原生美学、每工具独立色彩身份、状态页"bento"网格、绿/橙/红健康色语义）后，新增 `Features/Shared/FeatureVisuals.swift` 共享视觉组件（图标徽标、大数字统计、统一风险色常量、状态页动态配色），给每个功能页面分配一致的身份色并贯穿侧边栏图标→页面头部→主按钮，统一了此前分散不一致的风险徽标颜色。纯视觉层改动，未碰任何安全/业务逻辑代码，JingshanCore 无变化。
- **M14（创意布局，用户要求"来点创意的"）**：先做 HTML mockup，用 `.claude/launch.json` 新增本地预览服务器配置，通过 `preview_screenshot` 等工具真正渲染检查（过程中当场发现并修了两个 mockup 缺陷），用 Artifact 展示给用户确认方向后再落地成 SwiftUI：侧边栏改自定义 Button 列表+虚线小径+选中项抬起；Clean/Docker/Purge 页头换成 `ArcGauge` 弧形仪表盘（用 `Circle().trim` 而非手算角度）；状态页三个用量指标里当前最高的自动放大成主卡片。SwiftUI 实现本身仍未被截图验证过（原生 App 的限制没变）。
- **M15（修复"0 值"误导）**：`CleanViewModel`/`PurgeViewModel`/`DockerViewModel`/`StatusViewModel` 都加了"是否已经真正扫描/采样过一次"的标志位，未扫描时显示占位符/提示文案而非"0 KB"。
- **M16（系统监控口径校正）**：真机 `vm_stat`/`netstat` 核实后，内存"已用"公式改为 active+wired+compressed（原公式在这台机器上偏差约 3.5GB/22%）；网络吞吐排除常见虚拟/隧道网卡（真机当时有一个 VPN 隧道在跑，实测证实了旧逻辑会叠加统计）。
- **M17（深度扫描+收紧默认勾选）**：Clean 新增 5 个开发工具缓存位置；Docker 新增"未使用自定义网络"清理；Purge 新增 6 条语言生态规则（Go/Python tox/Turborepo/Nuxt/Angular/sbt）；Uninstaller 新增登录启动项残留扫描。同时把 Clean 的分类默认勾选、Uninstaller 的残留档位默认勾选都收紧为"只有最常用最安全的默认选中"。
- **M18（全面安全审计+全功能测试，数据安全第一）**：按用户"想办法用容器或沙箱等虚拟数据测试"的明确要求，用真实但完全隔离的 `jingshan-selftest-*` 前缀 Docker 资源验证了 Docker 模块的真实 CLI 行为，全程确认不影响真机已有的业务镜像，验证完全部清理并把 Docker 恢复到测试前的停止状态。独立审计对 M14-M17 做了复核，发现 1 项风险评级不一致（Docker 网络清理，已降级为 caution+默认不勾选）+ 补齐了新 Purge 规则的端到端测试，其余复查项目（LaunchAgents 前缀匹配、pip 去重、默认勾选一致性、扫描状态时序、内存公式溢出）均确认无实质缺陷。
- 全程 145 个单元测试，全部通过；每个里程碑后都做了构建+启动冒烟验证。

## 尚未开始 / 明确排除在当前范围外
- 正式 Developer ID 签名 + 公证 + DMG 分发（需要用户自己的 Apple Developer Program 账号）。
- 磁盘空间分析（`mo analyze`）、系统优化维护（`mo optimize`）、安装包清理（`mo installer`）。
- 更大的视觉/体验改动（M13/M14 都故意没做）：换图标、Status 历史曲线图、菜单栏 MenuBarExtra。
- 真实的界面点击走查（受限于当前会话缺少 Accessibility/Screen Recording 权限，只做了代码走查+编译+单元测试+启动冒烟测试；M14 的设计方向例外地用 HTML mockup 预览验证过）。

## 风险/注意事项
详见 docs/HANDOFF.md 的完整风险清单（符号链接删除语义、/private 黑名单策略、废纸篓特殊处理、Swift 6 并发坑、public init 要求、签名限制）。
