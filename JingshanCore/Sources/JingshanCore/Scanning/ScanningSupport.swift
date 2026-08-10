import Foundation

/// Shared helpers used by more than one category scanner.
enum ScanningSupport {
    /// Lists the immediate children of `directoryPath` as `ScannableItem`s,
    /// each sized independently. Used for categories where every child
    /// folder (e.g. one per bundle identifier under `~/Library/Caches`) is
    /// its own reviewable row, rather than one aggregate item for the whole
    /// directory.
    static func scanImmediateChildren(
        of directoryPath: String,
        excludedNames: Set<String> = [],
        ownerAppBundleID: (String) -> String? = { _ in nil }
    ) async -> (items: [ScannableItem], issues: [ScanIssue]) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directoryPath) else { return ([], []) }
        let names: [String]
        do {
            names = try fileManager.contentsOfDirectory(atPath: directoryPath)
        } catch {
            return ([], [ScanIssue(id: PathValidator.normalize(directoryPath), message: "无法读取此区域，扫描结果可能不完整")])
        }

        var items: [ScannableItem] = []
        for name in names {
            if Task.isCancelled { break }
            if name == ".DS_Store" || excludedNames.contains(name) { continue }

            let fullPath = (directoryPath as NSString).appendingPathComponent(name)
            let size = await FileSizeCalculator.sizeAsync(ofPath: fullPath)
            let attributes = try? fileManager.attributesOfItem(atPath: fullPath)
            let modified = attributes?[.modificationDate] as? Date

            items.append(
                ScannableItem(
                    id: PathValidator.normalize(fullPath),
                    path: fullPath,
                    sizeBytes: size,
                    ownerAppBundleID: ownerAppBundleID(name),
                    lastModified: modified
                )
            )
        }
        return (items, [])
    }

    /// A single aggregate item representing an entire directory (used for
    /// categories like Trash or a whole tool cache, where the natural unit
    /// of review is "the whole thing", not its individual contents).
    static func scanWholeDirectory(
        at path: String,
        displayLabel: String
    ) async -> ScannableItem? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let size = await FileSizeCalculator.sizeAsync(ofPath: path)
        return ScannableItem(
            id: PathValidator.normalize(path),
            path: path,
            sizeBytes: size,
            displayLabel: displayLabel
        )
    }

    /// Heuristic: does this directory name look like a reverse-DNS bundle
    /// identifier (e.g. "com.google.Chrome")? Used to opportunistically tag
    /// `~/Library/Caches` subfolders with an owning bundle id, since that is
    /// exactly how Caches folders are conventionally named.
    static func looksLikeBundleIdentifier(_ name: String) -> Bool {
        guard name.contains(".") else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_")
        return name.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
