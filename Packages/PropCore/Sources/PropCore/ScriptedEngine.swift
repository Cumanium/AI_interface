import Foundation

/// 台本モード。入力内容に関係なく、台本の台詞を順番に、生成しているような文字送りで返す。
///
/// 本番テイクの主力。毎回同じ台詞・同じタイミングで表示される。
@MainActor
public final class ScriptedEngine: ChatEngine {
    public typealias Sleeper = @Sendable (Duration) async throws -> Void

    public private(set) var cursor: ScriptCursor
    public var rhythm: TypingRhythm
    private let sleep: Sleeper

    public init(
        cursor: ScriptCursor,
        rhythm: TypingRhythm = .standard,
        sleep: @escaping Sleeper = { try await Task.sleep(for: $0) }
    ) {
        self.cursor = cursor
        self.rhythm = rhythm
        self.sleep = sleep
    }

    public func prepare(onStateChange: @escaping @MainActor @Sendable (EngineLoadState) -> Void) async throws {
        onStateChange(.ready)
    }

    public func reply(to userText: String) -> AsyncThrowingStream<ReplyEvent, Error> {
        let line = cursor.advance()
        let schedule = rhythm.schedule(for: line)
        let sleep = self.sleep
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for step in schedule {
                        try await sleep(step.delay)
                        continuation.yield(.delta(step.character))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func reset() {
        cursor.rewind()
    }

    /// 次に話す台詞を指定する。
    public func jump(to index: Int) {
        cursor.jump(to: index)
    }

    public func updateScript(_ script: Script, policy: ScriptExhaustionPolicy, fallbackLine: String) {
        cursor.replaceScript(script)
        cursor.exhaustionPolicy = policy
        cursor.fallbackLine = fallbackLine
    }
}
