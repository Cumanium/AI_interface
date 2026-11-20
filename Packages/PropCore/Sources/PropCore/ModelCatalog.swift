import Foundation

/// アプリで選べるローカルモデルの定義。
public struct ModelSpec: Sendable, Equatable, Hashable, Identifiable, Codable {
    /// Hugging Face のリポジトリ ID（例: `mlx-community/Qwen3-0.6B-4bit`）。
    public let id: String
    public let displayName: String
    /// 4bit 量子化時のおおよそのサイズ（MB）。
    public let approximateSizeMB: Int
    /// アプリに同梱するときのフォルダ名（`Resources/Models/<この名前>`）。
    public let bundledFolderName: String
    /// Hugging Face からダウンロードできるか。false のモデルは同梱が必須。
    public let isDownloadable: Bool
    /// `enable_thinking` などの思考モードを持つか（持つ場合はオフにして使う）。
    public let hasThinkingMode: Bool
    public let note: String

    public init(
        id: String,
        displayName: String,
        approximateSizeMB: Int,
        bundledFolderName: String,
        isDownloadable: Bool = true,
        hasThinkingMode: Bool = false,
        note: String
    ) {
        self.id = id
        self.displayName = displayName
        self.approximateSizeMB = approximateSizeMB
        self.bundledFolderName = bundledFolderName
        self.isDownloadable = isDownloadable
        self.hasThinkingMode = hasThinkingMode
        self.note = note
    }
}

public enum ModelCatalog {
    /// 第一候補。
    public static let qwen3_0_6B = ModelSpec(
        id: "mlx-community/Qwen3-0.6B-4bit",
        displayName: "Qwen3 0.6B (4bit)",
        approximateSizeMB: 350,
        bundledFolderName: "Qwen3-0.6B-4bit",
        hasThinkingMode: true,
        note: "第一候補。軽量で日本語も扱える。Apache 2.0"
    )

    public static let qwen3_1_7B = ModelSpec(
        id: "mlx-community/Qwen3-1.7B-4bit",
        displayName: "Qwen3 1.7B (4bit)",
        approximateSizeMB: 1000,
        bundledFolderName: "Qwen3-1.7B-4bit",
        hasThinkingMode: true,
        note: "品質を上げたいときの比較用"
    )

    public static let gemma3_1B = ModelSpec(
        id: "mlx-community/gemma-3-1b-it-qat-4bit",
        displayName: "Gemma 3 1B (QAT 4bit)",
        approximateSizeMB: 750,
        bundledFolderName: "gemma-3-1b-it-qat-4bit",
        note: "日本語の自然さの比較用。Gemma 利用規約"
    )

    /// MLX 形式の公開版がないため、Mac で変換して同梱する前提。
    public static let llmJP3_150M = ModelSpec(
        id: "local/llm-jp-3-150m-instruct3-4bit",
        displayName: "LLM-jp-3 150M instruct3 (要変換)",
        approximateSizeMB: 100,
        bundledFolderName: "llm-jp-3-150m-instruct3-4bit",
        isDownloadable: false,
        note: "最軽量の日本語特化。mlx_lm.convert で変換して同梱する。Apache 2.0"
    )

    public static let all: [ModelSpec] = [qwen3_0_6B, qwen3_1_7B, gemma3_1B, llmJP3_150M]
    public static let primary = qwen3_0_6B

    public static func spec(id: String) -> ModelSpec? {
        all.first { $0.id == id }
    }
}
