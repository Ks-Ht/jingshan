import Foundation

/// Finds `.app` bundles under the given root directories and reads just
/// enough of each `Info.plist` to identify it. Reads the plist directly
/// with `PropertyListSerialization` rather than going through `Bundle`, so
/// this stays a plain, synchronously-testable function over a fixture
/// directory tree instead of depending on `Bundle`'s own caching behavior.
public struct InstalledApplicationScanner: Sendable {
    private let protectedApps: ProtectedAppAllowlist

    public init(protectedApps: ProtectedAppAllowlist = .default) {
        self.protectedApps = protectedApps
    }

    /// `/Applications` always; `~/Applications` only if it actually exists,
    /// mirroring how macOS itself treats the per-user Applications folder
    /// as optional.
    public static func defaultRoots(fileManager: FileManager = .default) -> [String] {
        var roots = ["/Applications"]
        let userApplications = NSHomeDirectory() + "/Applications"
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: userApplications, isDirectory: &isDirectory), isDirectory.boolValue {
            roots.append(userApplications)
        }
        return roots
    }

    public func scan(roots: [String]) async -> [InstalledApplication] {
        let fileManager = FileManager.default
        var results: [InstalledApplication] = []
        for root in roots {
            guard let entries = try? fileManager.contentsOfDirectory(atPath: root) else { continue }
            for entry in entries.sorted() where entry.hasSuffix(".app") {
                if Task.isCancelled { return results }
                let appPath = root + "/" + entry
                guard var app = Self.readApplication(atPath: appPath, fileManager: fileManager) else { continue }
                // Excluded here (at scan time), not just at delete time:
                // protected apps should never even appear as a candidate to
                // uninstall, not merely be blocked once chosen.
                guard !protectedApps.isProtected(bundleIdentifier: app.bundleIdentifier) else { continue }
                app.sizeBytes = await FileSizeCalculator.sizeAsync(ofPath: appPath)
                results.append(app)
                await Task.yield()
            }
        }
        return results
    }

    static func readApplication(atPath path: String, fileManager: FileManager) -> InstalledApplication? {
        let infoPlistPath = path + "/Contents/Info.plist"
        guard let data = fileManager.contents(atPath: infoPlistPath),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let bundleIdentifier = plist["CFBundleIdentifier"] as? String,
            Self.isSafeAsPathComponent(bundleIdentifier)
        else {
            return nil
        }
        let fallbackName = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let candidateDisplayName = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? fallbackName
        // `bundleIdentifier`/`displayName` end up interpolated directly into
        // residual file paths (`ResidualLocationRule.expectedPath`), before
        // `PathValidator` ever sees the result. A crafted Info.plist value
        // containing "/" or ".." could otherwise make that computed path
        // escape its intended directory (e.g. a bundle id of "../../../etc"
        // turning "Library/Caches/<id>" into a path pointing at `/etc`). No
        // legitimate app ever has a "/" in either field, so reject rather
        // than merely fall back.
        let displayName = Self.isSafeAsPathComponent(candidateDisplayName) ? candidateDisplayName : fallbackName
        guard Self.isSafeAsPathComponent(displayName) else { return nil }
        let version = plist["CFBundleShortVersionString"] as? String
        return InstalledApplication(
            path: path,
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            versionString: version
        )
    }

    /// Rejects anything that could turn a single expected path component
    /// into more than one component, or into a no-op/parent-directory
    /// segment, when interpolated into a larger path string.
    private static func isSafeAsPathComponent(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".." && !value.contains("/")
    }
}
