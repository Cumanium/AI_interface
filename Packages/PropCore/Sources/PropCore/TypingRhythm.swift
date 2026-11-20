import Foundation

/// 台本モードで「AI が生成しているように」文字を送るリズム。
///
/// 撮影ではテイクごとに同じタイミングで表示されるほうが編集しやすいため、
/// 乱数は使わず、文字の種類だけで待ち時間を決める。
public struct TypingRhythm: Sendable, Equatable, Codable {
    /// 返答が始まるまでの「考えている」時間。
    public var thinkingDelay: Duration
    /// 1 文字あたりの基本の待ち時間。
    public var characterInterval: Duration
    /// 読点（、，）のあとに加える待ち時間。
    public var commaPause: Duration
    /// 句点・感嘆符・疑問符・改行のあとに加える待ち時間。
    public var sentencePause: Duration

    public init(
        thinkingDelay: Duration = .milliseconds(900),
        characterInterval: Duration = .milliseconds(45),
        commaPause: Duration = .milliseconds(120),
        sentencePause: Duration = .milliseconds(300)
    ) {
        self.thinkingDelay = thinkingDelay
        self.characterInterval = characterInterval
        self.commaPause = commaPause
        self.sentencePause = sentencePause
    }

    public static let standard = TypingRhythm()

    /// 1 文字ずつ、その文字を表示する前の待ち時間と組にして返す。
    public func schedule(for text: String) -> [(delay: Duration, character: String)] {
        var result: [(Duration, String)] = []
        result.reserveCapacity(text.count)
        var pendingPause: Duration = .zero
        for (offset, character) in text.enumerated() {
            let delay = (offset == 0 ? thinkingDelay : characterInterval) + pendingPause
            result.append((delay, String(character)))
            pendingPause = pause(after: character)
        }
        return result
    }

    /// 全文を表示し終えるまでの合計時間（撮影時の尺の目安）。
    public func totalDuration(for text: String) -> Duration {
        schedule(for: text).reduce(.zero) { $0 + $1.delay }
    }

    private func pause(after character: Character) -> Duration {
        switch character {
        case "、", "，", ",": commaPause
        case "。", "．", "！", "？", "!", "?", "\n", "…": sentencePause
        default: .zero
        }
    }
}
