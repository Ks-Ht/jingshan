import SwiftUI

/// The five modules' signature poems. (Previously this also carried a
/// per-motif procedural `Canvas` drawing — mountains, drifting clouds,
/// falling leaves, a rising sun — but the design feedback was that those
/// read as blurred smudges rather than ink wash, so the decoration was
/// reduced to a single clean `MountainSilhouette` and only the poems remain
/// here.)
enum InkWashMotif {
    case clean
    case docker
    case purge
    case uninstaller
    case largeFiles
    case status

    var poem: String {
        switch self {
        case .clean: return "山雨过后，尘随水去"
        case .docker: return "容器如云，聚散有时"
        case .purge: return "枯叶归尘，林自清明"
        case .uninstaller: return "移石拾遗，不留旧痕"
        case .largeFiles: return "重石移去，山自轻盈"
        case .status: return "登高望远，万象有序"
        }
    }
}
