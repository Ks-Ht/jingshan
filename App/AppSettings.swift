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
    /// sampling runs for it — the sampler is started/stopped right here so
    /// the promise actually holds (it used to run forever once started, and
    /// conversely never started when the tray was enabled mid-session).
    var menuBarEnabled: Bool {
        didSet {
            defaults.set(menuBarEnabled, forKey: Self.menuBarEnabledKey)
            if menuBarEnabled {
                MenuBarViewModel.shared.start()
            } else {
                MenuBarViewModel.shared.stop()
            }
        }
    }

    /// Menu-bar icon style: false = ink-mountain logo, true = live CPU%.
    var menuBarShowsPercent: Bool {
        didSet { defaults.set(menuBarShowsPercent, forKey: Self.menuBarShowsPercentKey) }
    }

    private(set) var exclusions: UserExclusionList
    /// Non-nil when the on-disk protection list could not be loaded or a
    /// requested edit could not be durably saved. Settings surfaces this so
    /// the UI never claims an exclusion is permanent when it is only in
    /// memory (or missing because the file is damaged).
    private(set) var exclusionPersistenceError: String?

    /// User-configured Purge scan roots. Empty means "use the defaults"
    /// (`~/workspace`, `~/Projects`, `~/Developer`, `~/GitHub`, `~/dev`) —
    /// mirrors Mole's `purge_paths`
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
        if FileManager.default.fileExists(atPath: exclusionsURL.path) {
            do {
                self.exclusions = try UserExclusionList.load(from: exclusionsURL)
                self.exclusionPersistenceError = nil
            } catch {
                // Fail closed. If a previously-saved protection list exists
                // but cannot be read, treating it as empty would silently
                // remove every user promise after restart. Protect the whole
                // home directory until the user repairs/replaces the file.
                self.exclusions = UserExclusionList(excludedPaths: [NSHomeDirectory()])
                self.exclusionPersistenceError = "受保护路径配置无法读取；为避免误删，已临时保护整个个人目录。\n\(error.localizedDescription)"
            }
        } else {
            self.exclusions = UserExclusionList()
            self.exclusionPersistenceError = nil
        }
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

    @discardableResult
    func addExclusion(path: String) -> Bool {
        var updated = exclusions
        updated.excludedPaths.insert(PathValidator.normalize(path))
        return persist(updated)
    }

    @discardableResult
    func removeExclusion(path: String) -> Bool {
        var updated = exclusions
        updated.excludedPaths.remove(path)
        updated.excludedPaths.remove(PathValidator.normalize(path))
        return persist(updated)
    }

    func clearExclusionPersistenceError() {
        exclusionPersistenceError = nil
    }

    private func persist(_ updated: UserExclusionList) -> Bool {
        do {
            // Commit to disk first. The in-memory/UI state changes only once
            // the user's "永不清理" promise is durable across relaunches.
            try updated.save(to: exclusionsURL)
            exclusions = updated
            exclusionPersistenceError = nil
            return true
        } catch {
            exclusionPersistenceError = "受保护路径未保存，设置没有生效。\n\(error.localizedDescription)"
            return false
        }
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
