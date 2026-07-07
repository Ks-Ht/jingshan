# 净山 (Jingshan)

一款 Swift 原生、非沙盒的 macOS 清理与系统监控工具。名字取自"空山"（呼应 kongshan.net）与"净"（清理）。

安全设计上参考了 [tw93/mole](https://github.com/tw93/mole) 的理念（不复用其 GPL-3.0 代码，是独立的 Swift 实现）：所有删除操作都经过统一的路径校验、关键路径黑名单、受保护应用名单，默认移动到废纸篓而非直接永久删除，并记录操作日志。

## 功能

- **清理**：按分类展示可清理的用户缓存、开发工具缓存（Xcode DerivedData、SwiftPM、Homebrew、pip、Cargo、Gradle 等）、浏览器缓存、日志、废纸篓，常见 App 会显示友好名称。
- **Docker 专项清理**：容器、镜像（悬空 + 未使用）、构建缓存、数据卷、未使用网络；Docker Desktop 完全退出时也能回收虚拟磁盘等宿主数据。
- **构建产物清理（Purge）**：扫描 `node_modules`、`target`、`.build`、`vendor`、`.venv` 等常见构建产物目录，覆盖 Node/Rust/Java/Scala/Swift/Python/Go/Gradle/CocoaPods/Turborepo/Nuxt/Angular 等生态，靠"同级目录是否有项目标志文件"防止误判。
- **应用卸载器**：卸载应用本体及其在系统各处留下的残留文件（缓存、偏好设置、登录启动项等），按风险分级，高风险项需二次确认。
- **系统状态监控**：实时 CPU / 内存 / 磁盘 / 网络。

默认只勾选最常用、最安全的清理项；风险较高的项目（运行中的容器、数据卷、沙盒容器数据等）永远不会被默认选中。

## 安装

### 通过 Homebrew（推荐）

```bash
brew tap kongshan-0924/jingshan https://github.com/kongshan-0924/jingshan
brew install --cask jingshan
```

净山目前是 ad-hoc 本机签名（没有 Apple Developer ID，没有公证）。Cask 安装脚本会在安装后自动清除隔离属性（quarantine），一般直接双击打开即可。如果仍然被 Gatekeeper 拦截，可以事后手动放行：

```bash
xattr -cr /Applications/净山.app
```

或者在 Finder 里右键点击 `净山.app` → 打开，在弹出的对话框里确认打开。

### 从源码构建

```bash
brew install xcodegen
git clone https://github.com/kongshan-0924/jingshan.git && cd jingshan
xcodegen generate
xcodebuild -project Jingshan.xcodeproj -scheme Jingshan -configuration Release build
```

构建产物在 `~/Library/Developer/Xcode/DerivedData/Jingshan-*/Build/Products/Release/净山.app`，`cp -R` 到 `/Applications/` 即可。

## 首次运行

净山需要**完全磁盘访问权限**才能扫描 `~/Library/Caches` 等位置——这是非沙盒 App 的系统级要求，不是这个 App 特有的限制。首次打开时应用会引导跳转到「系统设置 → 隐私与安全性 → 完全磁盘访问权限」，勾选净山后重新打开即可。

## 系统要求

- macOS 14 (Sonoma) 或更高版本
- 仅 Apple Silicon / Intel 均可（Swift 原生构建，未做架构限制）

## 开发

```bash
cd JingshanCore && swift test        # 核心逻辑单元测试
cd .. && xcodegen generate            # 改动 project.yml 或加/删源文件后需要重新生成工程
xcodebuild -project Jingshan.xcodeproj -scheme Jingshan -configuration Debug build
```

`Jingshan.xcodeproj` 是 `xcodegen` 从 `project.yml` 生成的派生产物，不提交到仓库；`JingshanCore` 是本地 Swift Package，包含全部安全敏感逻辑（路径校验、删除引擎、各类扫描器），与 UI 层完全解耦，可独立测试。

## 数据安全

删除操作只有一个入口（`DeletionEngine`），默认全部走废纸篓（可恢复），永久删除需要显式二次确认；每次操作都会记录到 `~/Library/Logs/Jingshan/operations.log`。详细的安全设计和历次审计记录见 `docs/HANDOFF.md`。

## License

暂未指定开源协议，个人项目性质，代码仅供参考。
