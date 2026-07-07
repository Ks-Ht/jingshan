import Foundation

/// One kind of build artifact directory Purge looks for.
///
/// Matching is deliberately NOT by name alone. A directory literally named
/// "build" or "target" is common enough as an unrelated, hand-made folder
/// (a user's own "build scripts" directory, a Java package named `target`,
/// etc.) that blind name matching would risk offering to delete something
/// that was never a compiler's output. Instead, a name only counts as a
/// match when at least one recognizable project marker file sits next to
/// it (e.g. `node_modules` only counts next to a `package.json`). This
/// mirrors the same "evidence-based, not name-based" caution the rest of
/// the app already applies (`CriticalPathDenylist`, `ProtectedAppAllowlist`).
public struct PurgeArtifactRule: Sendable, Equatable {
    public let directoryName: String
    public let displayLabel: String
    /// At least one of these must exist as a sibling of `directoryName` for
    /// it to count as a match. An empty array means the name is unambiguous
    /// enough on its own (see `__pycache__` below) and needs no marker.
    public let requiredSiblingMarkers: [String]
    public let riskNote: String

    public init(directoryName: String, displayLabel: String, requiredSiblingMarkers: [String], riskNote: String) {
        self.directoryName = directoryName
        self.displayLabel = displayLabel
        self.requiredSiblingMarkers = requiredSiblingMarkers
        self.riskNote = riskNote
    }

    /// Whether `directoryName` matches here, given the set of other entries
    /// found in the same parent directory.
    public func isSatisfied(bySiblingNames siblingNames: Set<String>) -> Bool {
        requiredSiblingMarkers.isEmpty || requiredSiblingMarkers.contains { siblingNames.contains($0) }
    }

    public static let defaultRules: [PurgeArtifactRule] = [
        PurgeArtifactRule(
            directoryName: "node_modules",
            displayLabel: "node_modules",
            requiredSiblingMarkers: ["package.json"],
            riskNote: "Node.js 依赖目录，删除后运行 npm/yarn/pnpm install 即可重新生成。"
        ),
        PurgeArtifactRule(
            directoryName: "target",
            displayLabel: "target（Rust/Java/Scala 构建产物）",
            requiredSiblingMarkers: ["Cargo.toml", "pom.xml", "build.sbt"],
            riskNote: "Rust（cargo build）、Java/Maven 或 Scala/sbt 的构建输出目录，删除后重新构建即可生成。"
        ),
        PurgeArtifactRule(
            directoryName: ".build",
            displayLabel: ".build（Swift 构建产物）",
            requiredSiblingMarkers: ["Package.swift"],
            riskNote: "Swift Package Manager 的构建输出目录，删除后重新构建即可生成。"
        ),
        PurgeArtifactRule(
            directoryName: "dist",
            displayLabel: "dist（前端构建产物）",
            requiredSiblingMarkers: ["package.json"],
            riskNote: "前端构建输出目录，删除后重新运行构建命令即可生成。"
        ),
        PurgeArtifactRule(
            directoryName: "build",
            displayLabel: "build（构建产物）",
            requiredSiblingMarkers: ["package.json", "build.gradle", "build.gradle.kts"],
            riskNote: "构建输出目录（Node/Gradle 项目常见），删除后重新构建即可生成。"
        ),
        PurgeArtifactRule(
            directoryName: ".next",
            displayLabel: ".next（Next.js 构建产物）",
            requiredSiblingMarkers: ["package.json"],
            riskNote: "Next.js 的构建缓存与产物目录，删除后重新运行 next build/dev 即可生成。"
        ),
        PurgeArtifactRule(
            directoryName: "venv",
            displayLabel: "venv（Python 虚拟环境）",
            requiredSiblingMarkers: ["pyproject.toml", "requirements.txt", "setup.py", "Pipfile"],
            riskNote: "Python 虚拟环境，删除后需要重新创建并安装依赖（pip install -r requirements.txt 等）。"
        ),
        PurgeArtifactRule(
            directoryName: ".venv",
            displayLabel: ".venv（Python 虚拟环境）",
            requiredSiblingMarkers: ["pyproject.toml", "requirements.txt", "setup.py", "Pipfile"],
            riskNote: "Python 虚拟环境，删除后需要重新创建并安装依赖（pip install -r requirements.txt 等）。"
        ),
        PurgeArtifactRule(
            directoryName: "__pycache__",
            displayLabel: "__pycache__（Python 字节码缓存）",
            requiredSiblingMarkers: [],
            riskNote: "Python 字节码缓存，运行时会自动重新生成，可安全删除。"
        ),
        PurgeArtifactRule(
            directoryName: ".gradle",
            displayLabel: ".gradle（Gradle 缓存）",
            requiredSiblingMarkers: ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"],
            riskNote: "Gradle 本地缓存，删除后下次构建会重新下载/生成，速度会变慢但不丢数据。"
        ),
        PurgeArtifactRule(
            directoryName: "Pods",
            displayLabel: "Pods（CocoaPods 依赖）",
            requiredSiblingMarkers: ["Podfile"],
            riskNote: "CocoaPods 依赖目录，删除后运行 pod install 即可重新生成。"
        ),
        PurgeArtifactRule(
            directoryName: "vendor",
            displayLabel: "vendor（Go 依赖）",
            requiredSiblingMarkers: ["go.mod"],
            riskNote: "Go 依赖目录（go mod vendor 生成），删除后重新运行 go mod vendor 或直接用模块缓存构建即可。"
        ),
        PurgeArtifactRule(
            directoryName: ".tox",
            displayLabel: ".tox（Python 测试环境）",
            requiredSiblingMarkers: ["tox.ini"],
            riskNote: "tox 为每个测试环境创建的虚拟环境缓存，删除后下次运行 tox 会重新创建。"
        ),
        PurgeArtifactRule(
            directoryName: ".turbo",
            displayLabel: ".turbo（Turborepo 缓存）",
            requiredSiblingMarkers: ["package.json"],
            riskNote: "Turborepo 的本地任务缓存，删除后下次构建会重新执行相关任务，速度变慢但不丢数据。"
        ),
        PurgeArtifactRule(
            directoryName: ".nuxt",
            displayLabel: ".nuxt（Nuxt 构建产物）",
            requiredSiblingMarkers: ["package.json"],
            riskNote: "Nuxt 的构建缓存与产物目录，删除后重新运行 nuxt build/dev 即可生成。"
        ),
        PurgeArtifactRule(
            directoryName: ".angular",
            displayLabel: ".angular（Angular 构建缓存）",
            requiredSiblingMarkers: ["angular.json"],
            riskNote: "Angular CLI 的构建缓存目录，删除后下次构建会重新生成，速度变慢但不丢数据。"
        ),
    ]
}
