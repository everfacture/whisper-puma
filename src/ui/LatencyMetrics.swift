import Foundation

final class LatencyMetrics {
    static let shared = LatencyMetrics()

    private let defaults = UserDefaults.standard
    private let key = "latency_samples_ms"
    private let maxSamples = 200

    private init() {}

    func addSample(ms: Double) {
        var samples = loadSamples()
        samples.append(ms)
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
        defaults.set(samples, forKey: key)
    }

    func summary() -> (last: Double?, p50: Double?, p95: Double?) {
        let samples = loadSamples()
        guard !samples.isEmpty else { return (nil, nil, nil) }
        let sorted = samples.sorted()
        let p50 = percentile(sorted, 50)
        let p95 = percentile(sorted, 95)
        return (samples.last, p50, p95)
    }

    private func loadSamples() -> [Double] {
        defaults.array(forKey: key) as? [Double] ?? []
    }

    private func percentile(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let idx = Int((p / 100.0) * Double(sorted.count - 1))
        return sorted[max(0, min(sorted.count - 1, idx))]
    }
}
