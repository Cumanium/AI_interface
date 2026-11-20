import PropCore
import SwiftUI

/// 撮影で映すチャット画面。
///
/// 設定画面は、画面上部の名前を 3 回タップすると開く（演者や画面に操作 UI を見せないため）。
struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var isShowingSettings = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messageList
            inputBar
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .topTrailing) {
            if viewModel.settings.showsDebugOverlay {
                DebugOverlay(loadState: viewModel.modelLoadState, stats: viewModel.lastStats, mode: viewModel.settings.mode)
                    .padding(.top, 56)
                    .padding(.trailing, 8)
            }
        }
        .sheet(isPresented: $isShowingSettings, onDismiss: viewModel.applySettings) {
            SettingsView(viewModel: viewModel, settingsStore: viewModel.settingsStore)
        }
        .task { await viewModel.preloadIfNeeded() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(viewModel.settings.persona.name)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture(count: 3) { isShowingSettings = true }
        .accessibilityAddTraits(.isHeader)
    }

    private var statusColor: Color {
        if viewModel.isResponding { return .orange }
        if viewModel.settings.mode == .generative, viewModel.modelLoadState != .ready { return .gray }
        return .green
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.last?.text) {
                guard let last = viewModel.messages.last else { return }
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("メッセージを入力", text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                .focused($isInputFocused)
                .onSubmit(viewModel.send)

            Button {
                if viewModel.isResponding { viewModel.stop() } else { viewModel.send() }
            } label: {
                Image(systemName: viewModel.isResponding ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
            }
            .disabled(!viewModel.isResponding && !viewModel.canSend)
            .accessibilityLabel(viewModel.isResponding ? "停止" : "送信")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(message.role == .user ? Color.white : Color.primary)
                .background(
                    message.role == .user ? Color.accentColor : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 18)
                )
            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if message.isStreaming && message.text.isEmpty {
            TypingIndicator()
        } else {
            Text(message.text + (message.isStreaming ? " ▍" : ""))
                .textSelection(.enabled)
        }
    }
}

/// 返答の 1 文字目が出るまでの「考え中」表示。
struct TypingIndicator: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 3
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .frame(width: 7, height: 7)
                        .opacity(index == step ? 1 : 0.3)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
        }
        .accessibilityLabel("返答を作成中")
    }
}

/// 開発・計測用の小さな表示。撮影時は設定でオフにする。
struct DebugOverlay: View {
    let loadState: EngineLoadState
    let stats: GenerationStats?
    let mode: ReplyMode

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("mode: \(mode.label)")
            Text("model: \(loadState.label)")
            if let stats {
                Text(String(format: "TTFT %.2fs / %.1f tok/s", stats.timeToFirstToken, stats.tokensPerSecond))
                if let peak = stats.peakMemoryBytes {
                    Text("peak \(peak / 1_048_576) MB")
                }
            }
        }
        .font(.caption2.monospaced())
        .padding(6)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
        .foregroundStyle(.white)
    }
}

extension EngineLoadState {
    var label: String {
        switch self {
        case .idle: "未読み込み"
        case .downloading(let fraction): "ダウンロード中 \(Int(fraction * 100))%"
        case .loading: "読み込み中"
        case .ready: "準備完了"
        case .failed(let message): "失敗: \(message)"
        }
    }
}
