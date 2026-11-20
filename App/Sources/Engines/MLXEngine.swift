import Foundation
import HuggingFace
import MLX
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import PropCore
import Tokenizers
import os

/// MLX Swift でローカル LLM を動かすエンジン（AI 生成モード）。
///
/// モデルの探し方:
/// 1. アプリに同梱した `Models/<bundledFolderName>` があればそれを読む（完全オフライン）。
/// 2. なければ Hugging Face からダウンロードする（初回のみネットワークが必要。以後はキャッシュ）。
final class MLXEngine: ChatEngine {
    let spec: ModelSpec
    var persona: Persona {
        didSet { if persona != oldValue { rebuildSession() } }
    }

    private var container: ModelContainer?
    private var session: ChatSession?
    private let logger = Logger(subsystem: "AIInterface", category: "MLXEngine")

    init(spec: ModelSpec, persona: Persona) {
        self.spec = spec
        self.persona = persona
    }

    /// 同梱モデルのフォルダ。safetensors が入っていなければ nil。
    var bundledDirectory: URL? { Self.bundledDirectory(for: spec) }

    static func bundledDirectory(for spec: ModelSpec) -> URL? {
        guard
            let url = Bundle.main.resourceURL?
                .appending(path: "Models", directoryHint: .isDirectory)
                .appending(path: spec.bundledFolderName, directoryHint: .isDirectory),
            let contents = try? FileManager.default.contentsOfDirectory(atPath: url.path(percentEncoded: false)),
            contents.contains(where: { $0.hasSuffix(".safetensors") })
        else { return nil }
        return url
    }

    func prepare(onStateChange: @escaping @MainActor @Sendable (EngineLoadState) -> Void) async throws {
        if container != nil {
            onStateChange(.ready)
            return
        }
        // GPU のバッファキャッシュを小さく抑えて、古い iPhone でのメモリ不足を防ぐ。
        Memory.cacheLimit = 20 * 1024 * 1024

        do {
            let loaded: ModelContainer
            if let directory = bundledDirectory {
                logger.info("Loading bundled model at \(directory.path(percentEncoded: false), privacy: .public)")
                onStateChange(.loading)
                loaded = try await LLMModelFactory.shared.loadContainer(
                    from: directory,
                    using: #huggingFaceTokenizerLoader()
                )
            } else if spec.isDownloadable {
                logger.info("Downloading model \(self.spec.id, privacy: .public)")
                onStateChange(.downloading(0))
                // 登録済みのモデルなら、EOS トークンなどの設定込みで取得できる。
                let configuration = LLMModelFactory.shared.configuration(id: spec.id)
                loaded = try await LLMModelFactory.shared.loadContainer(
                    from: #hubDownloader(),
                    using: #huggingFaceTokenizerLoader(),
                    configuration: configuration,
                    progress: LoadProgressHandlers(
                        download: { progress in
                            let fraction = progress.fractionCompleted
                            Task { @MainActor in onStateChange(.downloading(fraction)) }
                        },
                        weights: { _ in
                            Task { @MainActor in onStateChange(.loading) }
                        }
                    )
                )
            } else {
                throw MLXEngineError.modelNotBundled(spec)
            }
            container = loaded
            rebuildSession()
            onStateChange(.ready)
        } catch {
            onStateChange(.failed(error.localizedDescription))
            throw error
        }
    }

    func reply(to userText: String) -> AsyncThrowingStream<ReplyEvent, Error> {
        guard let session else {
            return AsyncThrowingStream { $0.finish(throwing: MLXEngineError.notPrepared) }
        }
        let details = session.streamDetails(to: userText)
        return AsyncThrowingStream { continuation in
            let task = Task {
                let start = ContinuousClock.now
                var firstTokenAt: Duration?
                do {
                    for try await generation in details {
                        switch generation {
                        case .chunk(let text):
                            if firstTokenAt == nil { firstTokenAt = ContinuousClock.now - start }
                            continuation.yield(.delta(text))
                        case .info(let info):
                            continuation.yield(.stats(GenerationStats(
                                timeToFirstToken: (firstTokenAt ?? .zero).seconds,
                                promptTokenCount: info.promptTokenCount,
                                generatedTokenCount: info.generationTokenCount,
                                promptTime: info.promptTime,
                                generateTime: info.generateTime,
                                peakMemoryBytes: Memory.peakMemory
                            )))
                        default:
                            // 思考（reasoning）やツール呼び出しは画面に出さない。
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func reset() {
        rebuildSession()
    }

    /// 人格や設定を反映した新しい会話を作る（文脈も消える）。
    private func rebuildSession() {
        guard let container else { return }
        let parameters = GenerateParameters(
            maxTokens: persona.maxTokens,
            temperature: persona.temperature,
            topP: persona.topP,
            repetitionPenalty: 1.1,
            seed: persona.seed
        )
        session = ChatSession(
            container,
            instructions: persona.systemPrompt,
            generateParameters: parameters,
            // Qwen3 の思考モードをオフにして、すぐ返答させる。
            additionalContext: spec.hasThinkingMode ? ["enable_thinking": false] : nil
        )
    }
}

nonisolated enum MLXEngineError: LocalizedError {
    case notPrepared
    case modelNotBundled(ModelSpec)

    var errorDescription: String? {
        switch self {
        case .notPrepared:
            "モデルの準備ができていません。"
        case .modelNotBundled(let spec):
            "\(spec.displayName) はアプリに同梱されていません。README の手順で Models/\(spec.bundledFolderName) に配置してください。"
        }
    }
}

nonisolated extension Duration {
    var seconds: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
