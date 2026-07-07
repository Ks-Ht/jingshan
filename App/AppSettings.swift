import Foundation
import JingshanCore

/// App-wide user preferences: the exclusion (protected-path) list and the
/// global dry-run "preview" mode. A single shared store so the Clean and
/// Docker flows, and the Settings screen, all read and write the same
/// state. The safety-critical enforcement lives in `DeletionEngine`
/// (exclusions) — this is just the glue that persists the user's choices
/// and hands the engine the right configuration.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    /// When on, every destructive action is turned into a preview: nothing
    /// is actually deleted, but the app reports what it *would* delete.
    var dryRunEnabled: Bool {
        didSet { defaults.set(dryRunEnabled, forKey: Self.dryRunKey) }
    }

    /// Whether the first-run welcome has been shown/completed. Drives the
    /// one-time `WelcomeSheet`.
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Self.hasCompletedOnboardingKey) }
    }

    /// Whether the menu-bar tray item is shown. When off, no background
    /// sampling runs for it.
    var menuBarEnabled: Bool {
        didSet { defaults.set(menuBarEnabled, forKey: Self.menuBarEnabledKey) }
    }

    /// Menu-bar icon style: false = ink-mountain logo, true = live CPU%.
    var menuBarShowsPercent: Bool {
        didSet { defaults.set(menuBarShowsPercent, forKey: Self.menuBarShowsPercentKey) }
    }

    private(set) var exclusions: UserExclusionList

    /// User-configured Purge scan roots. Empty means "use the defaults"
    /// (`~/Projects`, `~/GitHub`, `~/dev`) — mirrors Mole's `purge_paths`
    /// behavior: once the user configures anything, only those paths are
    /// scanned.
    private(set) var purgeScanPaths: [String] {
        didSet { defaults.set(purgeScanPaths, forKey: Self.purgeScanPathsKey) }
    }

    private let defaults: UserDefaults
    private let exclusionsURL: URL
    private static let dryRunKey = "net.kongshan.jingshan.dryRunEnabled"
    private static let purgeScanPathsKey = "net.kongshan.jingshan.purgeScanPaths"
    private static let hasCompletedOnboardingKey = "net.kongshan.jingshan.hasCompletedOnboarding"
    private static let menuBarEnabledKey = "net.kongshan.jingshan.menuBarEnabled"
    private static let menuBarShowsPercentKey = "net.kongshan.jingshan.menuBarShowsPercent"

    init(
        defaults: UserDefaults = .standard,
        exclusionsURL: URL = AppSettings.defaultExclusionsURL
    ) {
        self.defaults = defaults
        self.exclusionsURL = exclusionsURL
        self.dryRunEnabled = defaults.bool(forKey: Self.dryRunKey)
        self.hasCompletedOnboarding = defaults.bool(forKey: Self.hasCompletedOnboardingKey)
        self.menuBarEnabled = defaults.object(forKey: Self.menuBarEnabledKey) as? Bool ?? true
        self.menuBarShowsPercent = defaults.bool(forKey: Self.menuBarShowsPercentKey)
        self.exclusions = (try? UserExclusionList.load(from: exclusionsURL)) ?? UserExclusionList()
        self.purgeScanPaths = defaults.stringArray(forKey: Self.purgeScanPathsKey) ?? []
    }

    static var defaultExclusionsURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/Jingshan/exclusions.json")
    }

    // MARK: - Engine configuration

    /// A `DeletionEngine` configured with the current exclusion list, so an
    /// excluded path is refused even if it somehow reaches deletion.
    func makeDeletionEngine() -> DeletionEngine {
        DeletionEngine(exclusions: exclusions)
    }

    /// Maps a requested file-deletion intent to a mode, applying the global
    /// dry-run override.
    func fileDeletionMode(permanent: Bool) -> DeletionMode {
        if dryRunEnabled { return .dryRun }
        return permanent ? .permanent(confirmed: true) : .trash
    }

    var dockerCleanupMode: DockerCleanupMode {
        dryRunEnabled ? .dryRun : .real
    }

    func isExcluded(resolvedPath: String) -> Bool {
        exclusions.contains(resolvedPath: resolvedPath)
    }

    // MARK: - Exclusion editing

    var excludedPaths: [String] {
        exclusions.excludedPaths.sorted()
    }

    func addExclusion(path: String) {
        var updated = exclusions
        updated.excludedPaths.insert(PathValidator.normalize(path))
        persist(updated)
    }

    func removeExclusion(path: String) {
        var updated = exclusions
        updated.excludedPaths.remove(path)
        updated.excludedPaths.remove(PathValidator.normalize(path))
        persist(updated)
    }

    private func persist(_ updated: UserExclusionList) {
        exclusions = updated
        try? updated.save(to: exclusionsURL)
    }

    // MARK: - Purge scan paths

    func addPurgeScanPath(_ path: String) {
        var updated = purgeScanPaths
        let normalized = PathValidator.normalize(path)
        guard !updated.contains(normalized) else { return }
        updated.append(normalized)
        purgeScanPaths = updated
    }

    func removePurgeScanPath(_ path: String) {
        purgeScanPaths.removeAll { $0 == path }
    }

    /// The paths Purge should actually scan: the user's configured list if
    /// non-empty, otherwise the existence-filtered defaults.
    func effectivePurgeScanPaths(fileManager: FileManager = .default) -> [String] {
        guard purgeScanPaths.isEmpty else { return purgeScanPaths }
        return PurgeScanner.defaultRoots(fileManager: fileManager)
    }
}
