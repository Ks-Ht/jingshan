import Foundation
import JingshanCore

@MainActor
@Observable
final class StatusViewModel {
    private(set) var snapshot: SystemSnapshot = .empty

    private let sampler = SystemMetricsSampler()
    private var samplingTask: Task<Void, Never>?

    /// `.empty`'s sentinel `.distantPast` timestamp means "no real sample
    /// yet" — used so the UI can show a loading state instead of a
    /// misleading "0 B" for the fraction of a second before the first
    /// sample arrives.
    var hasSampledOnce: Bool { snapshot.timestamp != .distantPast }

    func start() {
        guard samplingTask == nil else { return }
        samplingTask = Task {
            while !Task.isCancelled {
                snapshot = await sampler.sample()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        samplingTask?.cancel()
        samplingTask = nil
    }
}
