import Foundation
import Testing

@testable import PropCore

struct ScriptParsingTests {
    @Test func splitsOnSeparatorAndSkipsComments() {
        let script = Script(parsing: """
            # S1
            こんにちは。
            ---
              # メモ
            一行目
            二行目
            ---

            ---
            最後です。
            """)
        #expect(script.lines == ["こんにちは。", "一行目\n二行目", "最後です。"])
    }

    @Test func emptyTextHasNoLines() {
        #expect(Script(parsing: "").lines.isEmpty)
        #expect(Script(parsing: "# だけ\n---\n").lines.isEmpty)
    }

    @Test func textRoundTrips() {
        let original = Script(lines: ["A", "B\nC", "D"])
        #expect(Script(parsing: original.text) == original)
    }
}

struct ScriptCursorTests {
    let script = Script(lines: ["一", "二"])

    @Test func fallbackAfterExhaustion() {
        var cursor = ScriptCursor(script: script, exhaustionPolicy: .fallback, fallbackLine: "予備")
        #expect([cursor.advance(), cursor.advance(), cursor.advance(), cursor.advance()] == ["一", "二", "予備", "予備"])
    }

    @Test func loopsAfterExhaustion() {
        var cursor = ScriptCursor(script: script, exhaustionPolicy: .loop, fallbackLine: "予備")
        #expect([cursor.advance(), cursor.advance(), cursor.advance()] == ["一", "二", "一"])
    }

    @Test func loopWithEmptyScriptUsesFallback() {
        var cursor = ScriptCursor(script: Script(lines: []), exhaustionPolicy: .loop, fallbackLine: "予備")
        #expect(cursor.advance() == "予備")
    }

    @Test(arguments: [(-3, 0), (1, 1), (99, 2)])
    func jumpClampsIndex(target: Int, expected: Int) {
        var cursor = ScriptCursor(script: script, fallbackLine: "")
        cursor.jump(to: target)
        #expect(cursor.nextIndex == expected)
    }

    @Test func replacingWithShorterScriptClampsIndex() {
        var cursor = ScriptCursor(script: script, fallbackLine: "")
        _ = cursor.advance()
        _ = cursor.advance()
        cursor.replaceScript(Script(lines: ["X"]))
        #expect(cursor.nextIndex == 1)
        #expect(cursor.isExhausted)
    }
}

struct TypingRhythmTests {
    let rhythm = TypingRhythm(
        thinkingDelay: .milliseconds(1000),
        characterInterval: .milliseconds(10),
        commaPause: .milliseconds(100),
        sentencePause: .milliseconds(500)
    )

    @Test func firstCharacterWaitsForThinkingDelay() {
        let schedule = rhythm.schedule(for: "はい、そう。で")
        #expect(schedule.map(\.character) == ["は", "い", "、", "そ", "う", "。", "で"])
        #expect(schedule.map(\.delay) == [
            .milliseconds(1000), .milliseconds(10), .milliseconds(10),
            .milliseconds(110), .milliseconds(10), .milliseconds(10), .milliseconds(510),
        ])
    }

    @Test func scheduleIsDeterministic() {
        #expect(rhythm.totalDuration(for: "同じ台詞。") == rhythm.totalDuration(for: "同じ台詞。"))
    }

    @Test func emptyTextHasNoSteps() {
        #expect(rhythm.schedule(for: "").isEmpty)
    }
}

@MainActor
struct ScriptedEngineTests {
    @Test func streamsCharactersInOrderAndRewinds() async throws {
        let engine = ScriptedEngine(
            cursor: ScriptCursor(script: Script(lines: ["あい", "う"]), fallbackLine: "予備"),
            sleep: { _ in }
        )
        #expect(try await collect(engine.reply(to: "x")) == "あい")
        #expect(try await collect(engine.reply(to: "x")) == "う")
        #expect(try await collect(engine.reply(to: "x")) == "予備")
        engine.reset()
        #expect(try await collect(engine.reply(to: "x")) == "あい")
    }

    @Test func jumpSelectsNextLine() async throws {
        let engine = ScriptedEngine(
            cursor: ScriptCursor(script: Script(lines: ["一", "二", "三"]), fallbackLine: ""),
            sleep: { _ in }
        )
        engine.jump(to: 2)
        #expect(try await collect(engine.reply(to: "")) == "三")
    }

    private func collect(_ stream: AsyncThrowingStream<ReplyEvent, Error>) async throws -> String {
        var text = ""
        for try await event in stream {
            if case .delta(let piece) = event { text += piece }
        }
        return text
    }
}

struct SettingsTests {
    @Test func settingsRoundTripThroughJSON() throws {
        var settings = PropSettings()
        settings.mode = .generative
        settings.persona.seed = nil
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(PropSettings.self, from: data) == settings)
    }

    @Test func defaultsUsePrimaryModelAndSampleScript() {
        let settings = PropSettings()
        #expect(settings.model == ModelCatalog.qwen3_0_6B)
        #expect(settings.script.lines.count == 3)
    }

    @Test func unknownModelFallsBackToPrimary() {
        #expect(PropSettings(modelID: "unknown/model").model == ModelCatalog.primary)
    }
}

struct BenchmarkSummaryTests {
    @Test func computesMedians() throws {
        let runs = [
            GenerationStats(timeToFirstToken: 0.3, promptTokenCount: 10, generatedTokenCount: 40, promptTime: 0.1, generateTime: 2, peakMemoryBytes: 100),
            GenerationStats(timeToFirstToken: 0.1, promptTokenCount: 10, generatedTokenCount: 30, promptTime: 0.1, generateTime: 1, peakMemoryBytes: 300),
            GenerationStats(timeToFirstToken: 0.2, promptTokenCount: 10, generatedTokenCount: 10, promptTime: 0.1, generateTime: 1, peakMemoryBytes: nil),
        ]
        let summary = try #require(BenchmarkSummary(runs))
        #expect(summary.runCount == 3)
        #expect(summary.medianTimeToFirstToken == 0.2)
        #expect(summary.medianTokensPerSecond == 20)
        #expect(summary.maxPeakMemoryBytes == 300)
    }

    @Test func emptyRunsHaveNoSummary() {
        #expect(BenchmarkSummary([]) == nil)
    }
}
