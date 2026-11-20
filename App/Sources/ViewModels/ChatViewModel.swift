import Foundation
import Observation
import PropCore

struct ChatMessage: Identifiable, Equatable {
    enum Role: Equatable {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    var text: String
    var isStreaming = false
}

/// チャット画面の状態。台本モードと AI 生成モードを切り替えて返答を流す。
@Observable
final class ChatViewModel {
    private(set) var messages: [ChatMessage] = []
    var draft = ""
    private(set) var isResponding = false
    /// AI 生成モードのモデル準備状況。
    private(set) var modelLoadState: EngineLoadState = .idle
    private(set) var lastStats: GenerationStats?

    let settingsStore: SettingsStore
    let scriptedEngine: ScriptedEngine
    private var mlxEngine: MLXEngine?
    private var replyTask: Task<Void, Never>?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        let settings = settingsStore.settings
        scriptedEngine = ScriptedEngine(
            cursor: ScriptCursor(
                script: settings.script,
                exhaustionPolicy: settings.exhaustionPolicy,
                fallbackLine: settings.fallbackLine
            ),
            rhythm: settings.rhythm
        )
    }

    var settings: PropSettings { settingsStore.settings }

    var canSend: Bool {
        !isResponding && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - 設定の反映

    /// 設定画面での変更をエンジンに反映する。
    func applySettings() {
        let settings = self.settings
        scriptedEngine.updateScript(settings.script, policy: settings.exhaustionPolicy, fallbackLine: settings.fallbackLine)
        scriptedEngine.rhythm = settings.rhythm

        if let mlxEngine, mlxEngine.spec != settings.model {
            // モデルが変わったら読み込み直す。
            self.mlxEngine = nil
            modelLoadState = .idle
        }
        mlxEngine?.persona = settings.persona
    }

    /// AI 生成モード用のエンジン。必要になったときに作る。
    func generativeEngine() -> MLXEngine {
        if let mlxEngine { return mlxEngine }
        let engine = MLXEngine(spec: settings.model, persona: settings.persona)
        mlxEngine = engine
        return engine
    }

    private var activeEngine: any ChatEngine {
        switch settings.mode {
        case .scripted: scriptedEngine
        case .generative: generativeEngine()
        }
    }

    /// AI 生成モードなら、撮影前にモデルを読み込んでおく。
    func preloadIfNeeded() async {
        guard settings.mode == .generative else { return }
        await prepareModel()
    }

    func prepareModel() async {
        if case .ready = modelLoadState { return }
        try? await generativeEngine().prepare { [weak self] state in
            self?.modelLoadState = state
        }
    }

    // MARK: - 送受信

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isResponding else { return }
        draft = ""
        messages.append(ChatMessage(role: .user, text: text))
        let reply = ChatMessage(role: .assistant, text: "", isStreaming: true)
        messages.append(reply)
        isResponding = true

        let engine = activeEngine
        replyTask = Task {
            await stream(from: engine, userText: text, into: reply.id)
        }
    }

    private func stream(from engine: any ChatEngine, userText: String, into id: ChatMessage.ID) async {
        let sentAt = ContinuousClock.now
        var firstDeltaAt: Duration?
        do {
            if engine !== scriptedEngine {
                try await engine.prepare { [weak self] state in
                    self?.modelLoadState = state
                }
            }
            for try await event in engine.reply(to: userText) {
                switch event {
                case .delta(let piece):
                    if firstDeltaAt == nil { firstDeltaAt = ContinuousClock.now - sentAt }
                    updateMessage(id) { $0.text += piece }
                case .stats(var stats):
                    // 準備時間も含めた、利用者から見た待ち時間に置き換える。
                    stats.timeToFirstToken = (firstDeltaAt ?? .zero).seconds
                    lastStats = stats
                }
            }
            updateMessage(id) { $0.text = $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
        } catch is CancellationError {
            // 停止ボタン。途中までの文字はそのまま残す。
        } catch {
            updateMessage(id) { $0.text += "\n（エラー: \(error.localizedDescription)）" }
        }
        updateMessage(id) { $0.isStreaming = false }
        isResponding = false
        replyTask = nil
    }

    func stop() {
        replyTask?.cancel()
    }

    /// 画面と文脈を消して、台本も最初に戻す（テイクの頭）。
    func resetConversation() {
        stop()
        messages.removeAll()
        lastStats = nil
        scriptedEngine.reset()
        mlxEngine?.reset()
    }

    private func updateMessage(_ id: ChatMessage.ID, _ change: (inout ChatMessage) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        change(&messages[index])
    }
}
