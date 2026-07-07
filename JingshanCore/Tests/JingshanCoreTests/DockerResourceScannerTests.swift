import Foundation
import Testing

@testable import JingshanCore

extension DockerRemovalMethod {
    var commandArguments: [String]? {
        if case .dockerCommand(let args) = self { return args }
        return nil
    }
}

@Suite("DockerResourceScanner")
struct DockerResourceScannerTests {
    @Test("classifies a running container as destructive and not selected by default")
    func runningContainerIsDestructive() async {
        let runner = FakeDockerCommandRunner()
        runner.setSuccess(
            for: ["ps", "-a", "-s", "--format", "{{json .}}"],
            output: #"{"ID":"abc123","Image":"redis:7","Names":"my-redis","State":"running","Status":"Up 4 days","Size":"0B (virtual 117MB)"}"#
        )
        let scanner = DockerResourceScanner(commandRunner: runner)

        let items = await scanner.scanContainers()

        #expect(items.count == 1)
        let item = try! #require(items.first)
        #expect(item.risk == .destructive)
        #expect(!item.defaultSelected)
        #expect(item.removal.commandArguments == ["rm", "-f", "abc123"])
    }

    @Test("classifies a stopped container as caution and selected by default")
    func stoppedContainerIsCautionAndSelected() async {
        let runner = FakeDockerCommandRunner()
        runner.setSuccess(
            for: ["ps", "-a", "-s", "--format", "{{json .}}"],
            output: #"{"ID":"def456","Image":"nginx:latest","Names":"old-nginx","State":"exited","Status":"Exited (0) 2 weeks ago","Size":"12MB (virtual 145MB)"}"#
        )
        let scanner = DockerResourceScanner(commandRunner: runner)

        let items = await scanner.scanContainers()

        #expect(items.count == 1)
        let item = try! #require(items.first)
        #expect(item.risk == .caution)
        #expect(item.defaultSelected)
        #expect(item.removal.commandArguments == ["rm", "def456"])
    }

    @Test("parses multiple NDJSON lines and skips malformed ones")
    func parsesMultipleLinesAndSkipsMalformed() async {
        let runner = FakeDockerCommandRunner()
        let goodLine = #"{"ID":"abc123","Image":"redis:7","Names":"my-redis","State":"running","Status":"Up 4 days","Size":"0B"}"#
        runner.setSuccess(
            for: ["ps", "-a", "-s", "--format", "{{json .}}"],
            output: "\(goodLine)\nnot valid json\n\(goodLine)"
        )
        let scanner = DockerResourceScanner(commandRunner: runner)

        let items = await scanner.scanContainers()
        #expect(items.count == 2)
    }

    @Test("dangling images are safe and selected by default")
    func danglingImagesAreSafe() async {
        let runner = FakeDockerCommandRunner()
        runner.setSuccess(
            for: ["images", "--filter", "dangling=true", "--format", "{{json .}}"],
            output: #"{"ID":"sha256:aaa111","Repository":"<none>","Tag":"<none>","CreatedSince":"3 weeks ago","Size":"245MB"}"#
        )
        let scanner = DockerResourceScanner(commandRunner: runner)

        let items = await scanner.scanDanglingImages()

        #expect(items.count == 1)
        let item = try! #require(items.first)
        #expect(item.risk == .safe)
        #expect(item.defaultSelected)
        #expect(item.sizeBytes == 245_000_000)
        #expect(item.removal.commandArguments == ["rmi", "sha256:aaa111"])
    }

    @Test("unused tagged images are caution, NOT default-selected, and removed by repo:tag without -f")
    func unusedTaggedImagesAreCautionNotDefault() async {
        let runner = FakeDockerCommandRunner()
        // Two tagged images; one (nginx:latest) is used by a container, the
        // other (oldapp:v1) is not.
        runner.setSuccess(
            for: ["images", "--format", "{{json .}}"],
            output: """
            {"ID":"sha256:aaa","Repository":"nginx","Tag":"latest","CreatedSince":"2 days ago","Size":"180MB"}
            {"ID":"sha256:bbb","Repository":"oldapp","Tag":"v1","CreatedSince":"6 months ago","Size":"900MB"}
            """
        )
        runner.setSuccess(
            for: ["ps", "-a", "--format", "{{json .}}"],
            output: #"{"ID":"c1","Image":"nginx:latest","Names":"web","State":"running","Status":"Up","Size":"0B"}"#
        )
        let scanner = DockerResourceScanner(commandRunner: runner)

        let items = await scanner.scanUnusedTaggedImages()

        #expect(items.count == 1)
        let item = try! #require(items.first)
        #expect(item.displayName == "oldapp:v1")
        #expect(item.risk == .caution)
        #expect(!item.defaultSelected)
        #expect(item.sizeBytes == 900_000_000)
        #expect(item.removal.commandArguments == ["rmi", "oldapp:v1"])
    }

    @Test("imageIsUsed matches by repo:tag, by short id, and by used-ref prefix")
    func imageUsageMatching() {
        #expect(DockerResourceScanner.imageIsUsed(reference: "nginx:latest", id: "sha256:abcdef123456789", usedReferences: ["nginx:latest"]))
        #expect(DockerResourceScanner.imageIsUsed(reference: "app:v1", id: "sha256:abcdef123456789", usedReferences: ["abcdef123456"]))
        #expect(DockerResourceScanner.imageIsUsed(reference: "app:v1", id: "sha256:abcdef123456789", usedReferences: ["abcdef1234"]))
        #expect(!DockerResourceScanner.imageIsUsed(reference: "app:v1", id: "sha256:abcdef123456789", usedReferences: ["nginx:latest", "999999999999"]))
    }

    @Test("build cache is reported as a single aggregate item")
    func buildCacheIsSingleAggregateItem() async {
        let runner = FakeDockerCommandRunner()
        let df = """
        {"Type":"Images","Reclaimable":"1.2GB (40%)"}
        {"Type":"Containers","Reclaimable":"80MB (66%)"}
        {"Type":"Local Volumes","Reclaimable":"200MB (40%)"}
        {"Type":"Build Cache","Reclaimable":"1.8GB (56%)"}
        """
        runner.setSuccess(for: ["system", "df", "--format", "{{json .}}"], output: df)
        let scanner = DockerResourceScanner(commandRunner: runner)

        let items = await scanner.scanBuildCache()

        #expect(items.count == 1)
        let item = try! #require(items.first)
        #expect(item.sizeBytes == 1_800_000_000)
        #expect(item.risk == .safe)
        #expect(item.defaultSelected)
        #expect(item.removal.commandArguments == ["builder", "prune", "-f"])
    }

    @Test("build cache with nothing reclaimable reports no item")
    func buildCacheWithZeroReclaimableReportsNoItem() async {
        let runner = FakeDockerCommandRunner()
        runner.setSuccess(for: ["system", "df", "--format", "{{json .}}"], output: #"{"Type":"Build Cache","Reclaimable":"0B"}"#)
        let scanner = DockerResourceScanner(commandRunner: runner)

        let items = await scanner.scanBuildCache()
        #expect(items.isEmpty)
    }

    @Test("dangling volumes are destructive, not selected by default, and never carry a size computed from the host filesystem")
    func danglingVolumesAreDestructive() async {
        let runner = FakeDockerCommandRunner()
        runner.setSuccess(
            for: ["volume", "ls", "--filter", "dangling=true", "--format", "{{json .}}"],
            output: #"{"Name":"old-db-data","Driver":"local"}"#
        )
        let scanner = DockerResourceScanner(commandRunner: runner)

        let items = await scanner.scanDanglingVolumes()

        #expect(items.count == 1)
        let item = try! #require(items.first)
        #expect(item.risk == .destructive)
        #expect(!item.defaultSelected)
        #expect(item.sizeBytes == nil)
        #expect(item.removal.commandArguments == ["volume", "rm", "old-db-data"])
    }

    @Test("a failing docker command degrades to an empty list rather than throwing")
    func failingCommandDegradesGracefully() async {
        let runner = FakeDockerCommandRunner()
        runner.setFailure(for: ["ps", "-a", "-s", "--format", "{{json .}}"], error: DockerCommandError.timedOut)
        let scanner = DockerResourceScanner(commandRunner: runner)

        let items = await scanner.scanContainers()
        #expect(items.isEmpty)
    }

    @Test("scanAll aggregates every daemon-side kind")
    func scanAllAggregatesEveryKind() async {
        let runner = FakeDockerCommandRunner()
        runner.setSuccess(
            for: ["ps", "-a", "-s", "--format", "{{json .}}"],
            output: #"{"ID":"abc123","Image":"redis:7","Names":"my-redis","State":"exited","Status":"Exited","Size":"0B"}"#
        )
        runner.setSuccess(
            for: ["images", "--filter", "dangling=true", "--format", "{{json .}}"],
            output: #"{"ID":"sha256:aaa111","Repository":"<none>","Tag":"<none>","CreatedSince":"3 weeks ago","Size":"245MB"}"#
        )
        runner.setSuccess(
            for: ["images", "--format", "{{json .}}"],
            output: #"{"ID":"sha256:bbb","Repository":"oldapp","Tag":"v1","CreatedSince":"6 months ago","Size":"900MB"}"#
        )
        runner.setSuccess(
            for: ["ps", "-a", "--format", "{{json .}}"],
            output: #"{"ID":"abc123","Image":"redis:7","Names":"my-redis","State":"exited","Status":"Exited","Size":"0B"}"#
        )
        runner.setSuccess(for: ["system", "df", "--format", "{{json .}}"], output: #"{"Type":"Build Cache","Reclaimable":"1.8GB"}"#)
        runner.setSuccess(
            for: ["volume", "ls", "--filter", "dangling=true", "--format", "{{json .}}"],
            output: #"{"Name":"old-db-data","Driver":"local"}"#
        )
        runner.setSuccess(
            for: ["network", "ls", "--filter", "type=custom", "--format", "{{json .}}"],
            output: #"{"ID":"net1","Name":"my-app-net","Driver":"bridge"}"#
        )
        let scanner = DockerResourceScanner(commandRunner: runner)

        let items = await scanner.scanAll()
        let kinds = Set(items.map(\.kind))
        #expect(kinds == [.container, .image, .buildCache, .volume, .network])
        // Containers come first so they can be removed before images.
        #expect(items.first?.kind == .container)
    }

    @Test("unused custom networks are a single caution-tier, NOT default-selected aggregate action")
    func unusedCustomNetworksAreCautionAndNotSelectedByDefault() async {
        // Tiered caution, not safe: "currently unused" can describe a
        // `docker compose stop`'d (not `down`'d) project's network just as
        // easily as a genuinely orphaned one — the same class of judgment
        // this file already tiers `.caution` for unused-tagged-images.
        let runner = FakeDockerCommandRunner()
        runner.setSuccess(
            for: ["network", "ls", "--filter", "type=custom", "--format", "{{json .}}"],
            output: #"{"ID":"net1","Name":"my-app-net","Driver":"bridge"}"#
                + "\n" + #"{"ID":"net2","Name":"another-net","Driver":"bridge"}"#
        )
        let scanner = DockerResourceScanner(commandRunner: runner)

        let items = await scanner.scanUnusedNetworks()

        #expect(items.count == 1)
        let item = try! #require(items.first)
        #expect(item.kind == .network)
        #expect(item.risk == .caution)
        #expect(!item.defaultSelected)
        #expect(item.removal.commandArguments == ["network", "prune", "-f"])
    }

    @Test("no custom networks means no network cleanup item")
    func noCustomNetworksMeansNoItem() async {
        let runner = FakeDockerCommandRunner()
        runner.setSuccess(for: ["network", "ls", "--filter", "type=custom", "--format", "{{json .}}"], output: "")
        let scanner = DockerResourceScanner(commandRunner: runner)

        let items = await scanner.scanUnusedNetworks()
        #expect(items.isEmpty)
    }
}
