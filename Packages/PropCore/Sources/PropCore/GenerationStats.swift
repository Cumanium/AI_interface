import Foundation

/// 1 回の生成の計測値。ベンチマーク画面と開発用オーバーレイで使う。
public struct GenerationStats: Sendable, Equatable, Codable {
    /// 送信から最初の文字が届くまでの秒数（Time To First Token）。
    public var timeToFirstToken: TimeInterval
    public var promptTokenCount: Int
    public var generatedTokenCount: Int
    /// プロンプト処理（prefill）にかかった秒数。
    public var promptTime: TimeInterval
    /// 生成（decode）にかかった秒数。
    public var generateTime: TimeInterval
    /// 計測時点のピークメモリ（バイト）。不明なら nil。
    public var peakMemoryBytes: Int?

    public init(
        timeToFirstToken: TimeInterval,
        promptTokenCount: Int,
        generatedTokenCount: Int,
        promptTime: TimeInterval,
        generateTime: TimeInterval,
        peakMemoryBytes: Int? = nil
    ) {
        self.timeToFirstToken = timeToFirstToken
        self.promptTokenCount = promptTokenCount
        self.generatedTokenCount = generatedTokenCount
        self.promptTime = promptTime
        self.generateTime = generateTime
        self.peakMemoryBytes = peakMemoryBytes
    }

    /// 生成速度（tokens/s）。
    public var tokensPerSecond: Double {
        generateTime > 0 ? Double(generatedTokenCount) / generateTime : 0
    }
}

/// 複数回の計測結果のまとめ。
public struct BenchmarkSummary: Sendable, Equatable {
    public let runCount: Int
    public let medianTimeToFirstToken: TimeInterval
    public let medianTokensPerSecond: Double
    public let maxPeakMemoryBytes: Int?

    public init?(_ runs: [GenerationStats]) {
        guard !runs.isEmpty else { return nil }
        runCount = runs.count
        medianTimeToFirstToken = Self.median(runs.map(\.timeToFirstToken))
        medianTokensPerSecond = Self.median(runs.map(\.tokensPerSecond))
        maxPeakMemoryBytes = runs.compactMap(\.peakMemoryBytes).max()
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
