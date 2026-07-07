# NEXT STEPS

## 关键决策(已确认,2026-07-05)
1. **技术栈**:Swift 原生开发。
2. **形态**:图形界面 Mac App。
3. **功能范围(MVP)**:垃圾/缓存清理 + 系统状态监控。**已实现并交付。**
4. **命名**:净山(Jingshan)。
5. **平台范围**:仅 macOS。
6. **非沙盒 + ad-hoc 本机签名**（已落地，`net.kongshan.jingshan`）。正式 Developer ID 签名/公证留给用户自己决定是否要做。
7. **工程生成工具 = xcodegen**，真源是 `project.yml`。

## 实施进度：M1-M18 全部完成
详见 docs/HANDOFF.md 的完整记录（含 M7 审计 9 项 + M10 审计 3 项 + M12 审计 4 项 + M18 审计 5 项发现与修复，各模块设计要点，以及 M13/M14 视觉设计系统说明）。App 已安装在 `/Applications/净山.app`，145 个单元测试全绿。当前功能：清理（分组，默认只勾选 App缓存/开发工具/浏览器三组）、Docker（宿主数据+运行时资源+未使用网络，Docker 停止时也能用）、项目构建产物清理（Purge，覆盖 Node/Rust/Java/Scala/Swift/Python/Go/Gradle/CocoaPods/Turborepo/Nuxt/Angular）、应用卸载器（Uninstaller，应用本体+残留文件含登录启动项，只有安全档默认勾选）、状态监控（内存/网络口径已按真机数据校正，三张卡片里用量最高的自动放大）、设置页（受保护路径+预览模式+构建产物扫描目录）。视觉上先后做过 M13（一致性配色）和 M14（路径式侧边栏+弧形仪表盘+动态非对称状态页）两轮优化。

## 如果继续迭代，建议顺序
1. **用户先看一遍 M14 创意布局的实际效果**（协助开发的一方没有 Accessibility/Screen Recording 权限，SwiftUI 实现本身没有被截图验证过，只有 HTML 设计稿被验证过）——路径式侧边栏、弧形仪表盘头部、状态页动态放大的主卡片。同时确认 M17 收紧后的默认勾选范围、M16 校正后的内存/网络数字是否符合预期。不满意可以具体指出哪一页/哪个元素需要调整，比笼统反馈"不好看"更容易改。
2. 继续走查功能本身：卸载应用页（建议先用不重要的小工具类应用测试一遍完整流程）、`AppCacheCatalog.json` 里没覆盖到的常见 App（发现一个加一条 JSON 记录即可，不用改代码逻辑）、Docker 页面在真实有容器/镜像/卷的机器上展示是否准确。
3. 更大的视觉/体验改动（M13/M14 都故意没做，只做了"整理现有页面"）：换图标、加状态历史曲线（Mole 桌面版有 60 秒走势图）、菜单栏小组件。
4. 正式分发：申请 Apple Developer Program → Xcode 里配置 Team/Developer ID 证书 → `notarytool` 公证 → 打 DMG。
6. 其余新功能（按需选择，讨论过但用户暂时选择先做 UI 优化+功能完善，还没定下一个做哪个）：
   - 磁盘空间分析（`mo analyze`，Mole 桌面版叫"Analyze"/treemap）—— 需要新的可视化浏览 UI（类似 DaisyDisk），比现有 List 展示复杂得多。
   - 系统优化维护（`mo optimize`）——涉及需要 sudo 的操作，安全设计需要专门评估（当前 `CriticalPathDenylist` 刻意没覆盖这类场景，授权/认证方式如 Touch ID 还是密码提权也需要和用户确认）。
   - Uninstaller 模块可扩展：`~/Library/Group Containers`（v1 故意跳过，group id 与 bundle id 无简单对应关系）；如果用户要卸载 Parallels/UTM/VMware 等其他虚拟化工具，需评估是否要像 Docker 一样加针对性存活检测（当前只覆盖 Docker 这一个已验证案例）。
   - Docker 模块 daemon 侧网络清理已实现（M17），可以进一步扩展的是 `~/.docker` 缓存子目录的精细化处理（需先确认哪些子目录纯缓存、哪些是配置，`~/.docker` 目前整体不碰）。

## 维护提醒（M7 审计发现，务必留意）
新增任何 `DevToolCacheScanner`/`BrowserCacheScanner` 里直接指向 `~/Library/Caches` 子目录的位置时，**必须**同步把对应文件夹名加进 `topLevelCacheNamesToExcludeFromGenericScan`（两个 scanner 各自维护一份，`UserCacheScanner` 取并集）。忘记这一步会导致该文件夹在"用户缓存"和对应专项分类里被重复展示、重复计入总大小——M7 审计中发现 SwiftPM/Homebrew 缓存就因为这个疏漏被漏排除过，M17 新增 pip 缓存位置时也同步做了处理，机制本身仍是人工维护，没有编译期/运行时保障。

## 已知限制（非阻塞，供后续参考）
- 协助开发的 Agent 目前无法对**原生 App**截图或做 Accessibility UI 验证（缺少"屏幕录制"和"辅助功能"权限）。M14 用 HTML mockup + 本地预览服务器的方式部分绕过了这个限制（验证了设计方向），但最终 SwiftUI 实现仍未被截图验证。如果用户希望以后能自动化验证，可以考虑把这两个权限授予跑 Claude Code 的终端 App。
- Metrics 模块的内存/网络口径 M16 已校正过（更接近 Activity Monitor 的口径），但仍是近似——不区分 App/Wired/Compressed 分别多少，网络仍是"所有物理网卡求和"而非"识别默认路由网卡"，Thunderbolt Bridge 作为主力网络连接会被误判为虚拟网卡漏统计（极罕见场景）。
- Docker 模块构建缓存作为单一聚合项处理，不支持逐条清理；"未使用自定义网络"清理评级为 caution+默认不勾选，且已用真机验证确认（`docker network prune` 不会因为存在非运行态容器引用而保护网络，`docker compose stop` 场景确实可能被误清），这是经过验证的正确评级，不需要再放宽。
