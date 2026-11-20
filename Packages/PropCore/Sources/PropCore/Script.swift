import Foundation

/// 台本モードで AI が話す台詞の並び。
///
/// テキスト形式:
/// - 台詞と台詞の間は `---` だけの行で区切る（1 つの台詞は複数行でもよい）。
/// - `#` で始まる行はコメントとして無視する（シーン番号のメモなどに使う）。
/// - 前後の空白・空行は取り除く。中身が空の台詞は数えない。
///
/// ```text
/// # S12 研究室
/// こんにちは。今日はどんなご用件ですか？
/// ---
/// 少し考えさせてください。
/// ……はい、わかりました。
/// ```
public struct Script: Sendable, Equatable {
    public static let separator = "---"

    public let lines: [String]

    public init(lines: [String]) {
        self.lines = lines
    }

    public init(parsing text: String) {
        var result: [String] = []
        var current: [String] = []

        func flush() {
            let joined = current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { result.append(joined) }
            current.removeAll()
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed == Self.separator {
                flush()
            } else if trimmed.hasPrefix("#") {
                continue
            } else {
                current.append(rawLine)
            }
        }
        flush()
        lines = result
    }

    /// テキスト形式に戻す（設定画面の編集用）。
    public var text: String {
        lines.joined(separator: "\n\(Self.separator)\n")
    }
}

/// 台本を使い切ったあとの振る舞い。
public enum ScriptExhaustionPolicy: String, Sendable, Codable, CaseIterable {
    /// 決めておいた予備の台詞を返す。
    case fallback
    /// 最初の台詞に戻る。
    case loop
}

/// 台本の「次に話す台詞」を管理する。入力内容には関係なく、順番に進む。
public struct ScriptCursor: Sendable, Equatable {
    public private(set) var script: Script
    /// 次に返す台詞の位置。
    public private(set) var nextIndex: Int = 0
    public var exhaustionPolicy: ScriptExhaustionPolicy
    public var fallbackLine: String

    public init(script: Script, exhaustionPolicy: ScriptExhaustionPolicy = .fallback, fallbackLine: String) {
        self.script = script
        self.exhaustionPolicy = exhaustionPolicy
        self.fallbackLine = fallbackLine
    }

    public var isExhausted: Bool { nextIndex >= script.lines.count }

    /// 次の台詞を取り出し、位置を 1 つ進める。
    public mutating func advance() -> String {
        if isExhausted {
            switch exhaustionPolicy {
            case .fallback:
                return fallbackLine
            case .loop:
                guard !script.lines.isEmpty else { return fallbackLine }
                nextIndex = 0
            }
        }
        let line = script.lines[nextIndex]
        nextIndex += 1
        return line
    }

    /// 次に話す台詞を指定する（撮り直しで途中のカットから始めるとき）。
    public mutating func jump(to index: Int) {
        nextIndex = min(max(0, index), script.lines.count)
    }

    public mutating func rewind() {
        nextIndex = 0
    }

    public mutating func replaceScript(_ newScript: Script) {
        script = newScript
        nextIndex = min(nextIndex, newScript.lines.count)
    }
}
