import Foundation
import Testing

@testable import JingshanCore

@Suite("DockerSizeParsing")
struct DockerSizeParsingTests {
    @Test(
        "parses plain Docker size strings",
        arguments: [
            ("0B", Int64(0)),
            ("245MB", Int64(245_000_000)),
            ("1.23GB", Int64(1_230_000_000)),
            ("512kB", Int64(512_000)),
            ("3.4TB", Int64(3_400_000_000_000)),
        ]
    )
    func parsesPlainSizes(text: String, expectedBytes: Int64) {
        #expect(DockerSizeParsing.parseBytes(from: text) == expectedBytes)
    }

    @Test("returns nil for N/A")
    func returnsNilForNA() {
        #expect(DockerSizeParsing.parseBytes(from: "N/A") == nil)
    }

    @Test("returns nil for unparseable garbage")
    func returnsNilForGarbage() {
        #expect(DockerSizeParsing.parseBytes(from: "not a size") == nil)
        #expect(DockerSizeParsing.parseBytes(from: "") == nil)
    }

    @Test("parseLeadingBytes strips parenthetical context")
    func parseLeadingBytesStripsParens() {
        #expect(DockerSizeParsing.parseLeadingBytes(from: "1.8GB (56%)") == 1_800_000_000)
        #expect(DockerSizeParsing.parseLeadingBytes(from: "0B (virtual 117MB)") == 0)
    }
}
