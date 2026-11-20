import Foundation

/// 返答の生成中に流れてくるイベント。
public enum ReplyEvent: Sendable, Equatable {
    /// 画面に追記する文字列（1 文字〜数トークン分）。
    case delta(String)
    /// 生成が終わったときの計測値。台本モードでは流れない。
    case stats(GenerationStats)
}

/// エンジンの準備状況。
public enum EngineLoadState: Sendable, Equatable {
    case idle
    /// モデルのダウンロード中（0.0〜1.0）。
    case downloading(Double)
    /// モデルの重みを読み込み中。
    case loading
    case ready
    case failed(String)
}

/// 返答を作る仕組みの共通インターフェース。
///
/// 台本モード（`ScriptedEngine`）とローカル LLM（アプリ側の `MLXEngine`）を
/// 同じ画面から切り替えられるようにするための抽象。
@MainActor
public protocol ChatEngine: AnyObject {
    /// モデルの読み込みなど、最初の返答の前に必要な準備をする。何度呼んでもよい。
    func prepare(onStateChange: @escaping @MainActor @Sendable (EngineLoadState) -> Void) async throws

    /// ユーザーの発言に対する返答をストリーミングで返す。
    func reply(to userText: String) -> AsyncThrowingStream<ReplyEvent, Error>

    /// 会話の文脈を消して最初からやり直す（テイクの頭に戻す）。
    func reset()
}
