import Foundation
import Testing

@testable import JingshanCore

@Suite("PurgeScanner")
struct PurgeScannerTests {
    private let fm = FileManager.default

    @Test("finds node_modules only when package.json sits next to it")
    func findsNodeModulesOnlyWithPackageJSON() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }

        let realProject = root.appendingPathComponent("my-app", isDirectory: true)
        try fm.createDirectory(at: realProject.appendingPathComponent("node_modules/some-pkg"), withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: realProject.appendingPathComponent("package.json"), contents: "{}")

        let fakeProject = root.appendingPathComponent("not-a-project", isDirectory: true)
        try fm.createDirectory(at: fakeProject.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        // Deliberately no package.json here.

        let scanner = PurgeScanner()
        let found = await scanner.scan(roots: [root.path])

        #expect(found.count == 1)
        #expect(found.first?.path == realProject.appendingPathComponent("node_modules").path)
        #expect(found.first?.projectName == "my-app")
    }

    @Test("finds Python's .tox directory only when tox.ini sits next to it")
    func findsToxOnlyWithToxIni() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }

        let realProject = root.appendingPathComponent("py-service", isDirectory: true)
        try fm.createDirectory(at: realProject.appendingPathComponent(".tox/py311"), withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: realProject.appendingPathComponent("tox.ini"), contents: "[tox]")

        let fakeProject = root.appendingPathComponent("unrelated-dotfolder", isDirectory: true)
        try fm.createDirectory(at: fakeProject.appendingPathComponent(".tox"), withIntermediateDirectories: true)
        // Deliberately no tox.ini here.

        let scanner = PurgeScanner()
        let found = await scanner.scan(roots: [root.path])

        #expect(found.count == 1)
        #expect(found.first?.path == realProject.appendingPathComponent(".tox").path)
    }

    @Test("finds Angular's .angular cache only when angular.json sits next to it")
    func findsAngularCacheOnlyWithAngularJSON() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }

        let realProject = root.appendingPathComponent("ng-app", isDirectory: true)
        try fm.createDirectory(at: realProject.appendingPathComponent(".angular/cache"), withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: realProject.appendingPathComponent("angular.json"), contents: "{}")

        let fakeProject = root.appendingPathComponent("not-angular", isDirectory: true)
        try fm.createDirectory(at: fakeProject.appendingPathComponent(".angular"), withIntermediateDirectories: true)
        // A package.json alone (no angular.json) must not be enough — this
        // rule is deliberately gated on angular.json, not the more generic
        // package.json every JS project has.
        try TestFixtures.writeFile(at: fakeProject.appendingPathComponent("package.json"), contents: "{}")

        let scanner = PurgeScanner()
        let found = await scanner.scan(roots: [root.path])

        #expect(found.count == 1)
        #expect(found.first?.path == realProject.appendingPathComponent(".angular").path)
    }

    @Test("target rule also matches for Scala/sbt projects via the build.sbt marker")
    func findsScalaTargetWithSbtMarker() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }

        let realProject = root.appendingPathComponent("scala-service", isDirectory: true)
        try fm.createDirectory(at: realProject.appendingPathComponent("target/scala-3.3.1"), withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: realProject.appendingPathComponent("build.sbt"), contents: "name := \"svc\"")

        let scanner = PurgeScanner()
        let found = await scanner.scan(roots: [root.path])

        #expect(found.count == 1)
        #expect(found.first?.path == realProject.appendingPathComponent("target").path)
    }

    @Test("finds Go's vendor directory only when go.mod sits next to it")
    func findsGoVendorOnlyWithGoMod() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }

        let realProject = root.appendingPathComponent("go-service", isDirectory: true)
        try fm.createDirectory(at: realProject.appendingPathComponent("vendor/some-pkg"), withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: realProject.appendingPathComponent("go.mod"), contents: "module example.com/svc")

        let fakeProject = root.appendingPathComponent("not-a-go-project", isDirectory: true)
        try fm.createDirectory(at: fakeProject.appendingPathComponent("vendor"), withIntermediateDirectories: true)
        // Deliberately no go.mod here — could be a hand-made "vendor" folder.

        let scanner = PurgeScanner()
        let found = await scanner.scan(roots: [root.path])

        #expect(found.count == 1)
        #expect(found.first?.path == realProject.appendingPathComponent("vendor").path)
    }

    @Test("a matched artifact directory is never recursed into, even if it contains a nested match")
    func matchedDirectoryIsNotRecursedInto() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }

        let project = root.appendingPathComponent("monorepo", isDirectory: true)
        let outerModules = project.appendingPathComponent("node_modules", isDirectory: true)
        try fm.createDirectory(at: outerModules, withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: project.appendingPathComponent("package.json"), contents: "{}")

        // A nested package with its own node_modules + package.json, deep
        // inside the outer node_modules — common in real JS monorepos.
        let nestedPackage = outerModules.appendingPathComponent("some-lib", isDirectory: true)
        try fm.createDirectory(at: nestedPackage.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: nestedPackage.appendingPathComponent("package.json"), contents: "{}")

        let scanner = PurgeScanner()
        let found = await scanner.scan(roots: [root.path])

        // Only the outer node_modules should be reported — deleting it
        // already deletes everything nested, so the inner one must not
        // also show up as a separate, double-counted candidate.
        #expect(found.count == 1)
        #expect(found.first?.path == outerModules.path)
    }

    @Test("never follows a symlink while walking, and does not hang on a symlink cycle")
    func doesNotFollowSymlinks() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }

        let project = root.appendingPathComponent("app", isDirectory: true)
        try fm.createDirectory(at: project, withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: project.appendingPathComponent("package.json"), contents: "{}")

        // A symlink that points back at the project root itself — if the
        // scanner ever followed it, this would recurse forever.
        let cyclicLink = project.appendingPathComponent("link-to-self")
        try fm.createSymbolicLink(at: cyclicLink, withDestinationURL: project)

        // A symlinked node_modules elsewhere — must not be treated as a
        // real, in-place node_modules to purge.
        let realModulesElsewhere = root.appendingPathComponent("elsewhere/node_modules", isDirectory: true)
        try fm.createDirectory(at: realModulesElsewhere, withIntermediateDirectories: true)
        let linkedModules = project.appendingPathComponent("node_modules")
        try fm.createSymbolicLink(at: linkedModules, withDestinationURL: realModulesElsewhere)

        let scanner = PurgeScanner()
        let found = await scanner.scan(roots: [root.path])

        // Terminates (no hang) and reports nothing: the only "node_modules"
        // reachable from `project` is a symlink, which must be skipped.
        #expect(found.isEmpty)
    }

    @Test("never descends into .git")
    func skipsGitDirectory() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }

        let gitInternal = root.appendingPathComponent(".git/fake-node-project", isDirectory: true)
        try fm.createDirectory(at: gitInternal.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: gitInternal.appendingPathComponent("package.json"), contents: "{}")

        let scanner = PurgeScanner()
        let found = await scanner.scan(roots: [root.path])

        #expect(found.isEmpty)
    }

    @Test("respects the configured maximum recursion depth")
    func respectsMaxDepth() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }

        // Nest a real project 5 levels deep.
        var deep = root
        for level in 0..<5 {
            deep = deep.appendingPathComponent("level\(level)", isDirectory: true)
        }
        try fm.createDirectory(at: deep.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: deep.appendingPathComponent("package.json"), contents: "{}")

        let shallow = PurgeScanner(maxDepth: 2)
        #expect(await shallow.scan(roots: [root.path]).isEmpty)

        let generous = PurgeScanner(maxDepth: 10)
        #expect(await generous.scan(roots: [root.path]).count == 1)
    }

    @Test("a project modified within the recency threshold is flagged isRecent")
    func flagsRecentlyModifiedProjects() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }

        let recentProject = root.appendingPathComponent("recent-app", isDirectory: true)
        try fm.createDirectory(at: recentProject.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: recentProject.appendingPathComponent("package.json"), contents: "{}")
        // Freshly created: mtime is "now", within the recency window.

        let oldProject = root.appendingPathComponent("old-app", isDirectory: true)
        try fm.createDirectory(at: oldProject.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try TestFixtures.writeFile(at: oldProject.appendingPathComponent("package.json"), contents: "{}")
        let oldDate = Date().addingTimeInterval(-30 * 86400)
        try fm.setAttributes([.modificationDate: oldDate], ofItemAtPath: oldProject.path)

        let scanner = PurgeScanner(recentThresholdDays: 7)
        let found = await scanner.scan(roots: [root.path])

        let recent = try #require(found.first { $0.projectName == "recent-app" })
        let old = try #require(found.first { $0.projectName == "old-app" })
        #expect(recent.isRecent)
        #expect(!old.isRecent)
    }

    @Test("returns nothing for a root that does not exist")
    func emptyWhenRootMissing() async throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }
        let missing = root.appendingPathComponent("does-not-exist").path

        let scanner = PurgeScanner()
        let found = await scanner.scan(roots: [missing])
        #expect(found.isEmpty)
    }

    @Test("defaultRoots only returns paths that actually exist")
    func defaultRootsFiltersToExisting() throws {
        let root = try TestFixtures.makeScratchDirectory()
        defer { TestFixtures.removeIfNeeded(root) }
        try fm.createDirectory(at: root.appendingPathComponent("Projects"), withIntermediateDirectories: true)
        // "GitHub" and "dev" deliberately left absent.

        let roots = PurgeScanner.defaultRoots(homeDirectory: root.path)
        #expect(roots == [root.appendingPathComponent("Projects").path])
    }
}
