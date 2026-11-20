import Observation
import PropCore
import SwiftUI

/// 実機でモデルの速度と返答の質を確かめるための計測。
@Observable
final class BenchmarkViewModel {
    struct Run: Identifiable {
        let id = UUID()
        let prompt: String
        let output: String
        let stats: GenerationStats?
    }

    static let prompts = [
        "こんにちは。あなたは誰ですか？",
        "今日はなんだか疲れてしまいました。",
        "おすすめの気分転換を一つ教えてください。",
        "明日の天気が心配です。",
        "ありがとう。また話しかけてもいいですか？",
    ]

    let engine: MLXEngine
    private(set) var runs: [Run] = []
    private(set) var isRunning = false
    private(set) var loadState: EngineLoadState = .idle
    private(set) var errorMessage: String?

    init(engine: MLXEngine) {
        self.engine = engine
    }

    var summary: BenchmarkSummary? {
        BenchmarkSummary(runs.compactMap(\.stats))
    }

    func run() async {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil
        runs.removeAll()
        defer {
            // 計測で使った文脈を、チャット画面に持ち越さない。
            engine.reset()
            isRunning = false
        }
        do {
            try await engine.prepare { [weak self] state in self?.loadState = state }
            for prompt in Self.prompts {
                // 各質問を独立に測るため、毎回文脈を消す。
                engine.reset()
                let start = ContinuousClock.now
                var firstDeltaAt: Duration?
                var output = ""
                var stats: GenerationStats?
                for try await event in engine.reply(to: prompt) {
                    switch event {
                    case .delta(let piece):
                        if firstDeltaAt == nil { firstDeltaAt = ContinuousClock.now - start }
                        output += piece
                    case .stats(var value):
                        value.timeToFirstToken = (firstDeltaAt ?? .zero).seconds
                        stats = value
                    }
                }
                runs.append(Run(prompt: prompt, output: output.trimmingCharacters(in: .whitespacesAndNewlines), stats: stats))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BenchmarkView: View {
    let viewModel: BenchmarkViewModel

    var body: some View {
        List {
            Section {
                LabeledContent("モデル", value: viewModel.engine.spec.displayName)
                LabeledContent("状態", value: viewModel.loadState.label)
                Button(viewModel.isRunning ? "計測中…" : "\(BenchmarkViewModel.prompts.count) 問で計測する") {
                    Task { await viewModel.run() }
                }
                .disabled(viewModel.isRunning)
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }

            if let summary = viewModel.summary {
                Section("まとめ（中央値）") {
                    LabeledContent("最初の文字まで", value: String(format: "%.2f 秒", summary.medianTimeToFirstToken))
                    LabeledContent("生成速度", value: String(format: "%.1f tok/s", summary.medianTokensPerSecond))
                    if let peak = summary.maxPeakMemoryBytes {
                        LabeledContent("ピークメモリ（起動から）", value: "\(peak / 1_048_576) MB")
                    }
                }
            }

            Section("返答（口調と自然さを目視で確認）") {
                ForEach(viewModel.runs) { run in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(run.prompt).font(.caption).foregroundStyle(.secondary)
                        Text(run.output)
                        if let stats = run.stats {
                            Text(String(format: "TTFT %.2fs / %.1f tok/s / %d tok", stats.timeToFirstToken, stats.tokensPerSecond, stats.generatedTokenCount))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("ベンチマーク")
    }
}
