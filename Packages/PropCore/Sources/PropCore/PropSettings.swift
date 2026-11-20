import Foundation

/// 返答の出し方。
public enum ReplyMode: String, Sendable, Codable, CaseIterable, Identifiable {
    /// 台本の台詞を順に表示する（本番テイク用）。
    case scripted
    /// ローカル LLM が実際に生成する（アドリブ・メイキング用）。
    case generative

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .scripted: "台本"
        case .generative: "AI 生成"
        }
    }
}

/// 作中 AI の人格とサンプリング設定。
public struct Persona: Sendable, Equatable, Codable {
    /// 画面上部に出す AI の名前。
    public var name: String
    /// システムプロンプト。
    public var systemPrompt: String
    public var temperature: Float
    public var topP: Float
    public var maxTokens: Int
    /// 固定すると、同じ入力に対して同じ返答が出やすくなる。nil ならランダム。
    public var seed: UInt64?

    public init(
        name: String,
        systemPrompt: String,
        temperature: Float,
        topP: Float,
        maxTokens: Int,
        seed: UInt64?
    ) {
        self.name = name
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.seed = seed
    }

    public static let `default` = Persona(
        name: "AI",
        systemPrompt: """
            あなたは穏やかで中立的な AI アシスタントです。
            必ず日本語で、丁寧な「です・ます」調で答えてください。
            返答は 1〜3 文の短さにまとめてください。
            箇条書き、絵文字、英語、Markdown の記号は使わないでください。
            """,
        temperature: 0.7,
        topP: 0.8,
        maxTokens: 160,
        seed: 42
    )
}

/// アプリ全体の設定。UserDefaults に JSON で保存する。
public struct PropSettings: Sendable, Equatable, Codable {
    public var mode: ReplyMode
    public var modelID: String
    public var persona: Persona
    public var scriptText: String
    public var exhaustionPolicy: ScriptExhaustionPolicy
    public var fallbackLine: String
    public var rhythm: TypingRhythm
    /// 計測値を画面の隅に小さく出す（撮影時はオフ）。
    public var showsDebugOverlay: Bool

    public init(
        mode: ReplyMode = .scripted,
        modelID: String = ModelCatalog.primary.id,
        persona: Persona = .default,
        scriptText: String = PropSettings.sampleScript,
        exhaustionPolicy: ScriptExhaustionPolicy = .fallback,
        fallbackLine: String = "申し訳ありません。もう一度お願いできますか？",
        rhythm: TypingRhythm = .standard,
        showsDebugOverlay: Bool = false
    ) {
        self.mode = mode
        self.modelID = modelID
        self.persona = persona
        self.scriptText = scriptText
        self.exhaustionPolicy = exhaustionPolicy
        self.fallbackLine = fallbackLine
        self.rhythm = rhythm
        self.showsDebugOverlay = showsDebugOverlay
    }

    public var model: ModelSpec {
        ModelCatalog.spec(id: modelID) ?? ModelCatalog.primary
    }

    public var script: Script {
        Script(parsing: scriptText)
    }

    public static let sampleScript = """
        # サンプル台本（設定画面で書き換えてください）
        こんにちは。今日はどんなご用件でしょうか？
        ---
        なるほど、少し考えさせてください。
        ……はい。それなら、まず深呼吸をしてみるのはいかがでしょう。
        ---
        どういたしまして。またいつでも話しかけてくださいね。
        """
}
