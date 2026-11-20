import PropCore
import SwiftUI

/// 撮影スタッフ向けの設定画面。
struct SettingsView: View {
    let viewModel: ChatViewModel
    @Bindable var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var nextLineIndex = 0
    @State private var benchmarkModel: BenchmarkViewModel?
    @State private var isShowingBenchmark = false

    var body: some View {
        NavigationStack {
            Form {
                modeSection
                takeSection
                scriptSection
                rhythmSection
                modelSection
                personaSection
                Section {
                    Toggle("計測値を画面に表示", isOn: $settingsStore.settings.showsDebugOverlay)
                    Button("すべての設定を初期値に戻す", role: .destructive) {
                        settingsStore.restoreDefaults()
                    }
                } header: {
                    Text("その他")
                }
            }
            .navigationDestination(isPresented: $isShowingBenchmark) {
                if let benchmarkModel {
                    BenchmarkView(viewModel: benchmarkModel)
                }
            }
            .onAppear { nextLineIndex = viewModel.scriptedEngine.cursor.nextIndex }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    // MARK: - セクション

    private var modeSection: some View {
        Section {
            Picker("返答の出し方", selection: $settingsStore.settings.mode) {
                ForEach(ReplyMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        } footer: {
            Text("本番テイクは「台本」、アドリブやメイキングは「AI 生成」を想定しています。")
        }
    }

    private var takeSection: some View {
        Section {
            Button("会話を消して台本の頭に戻す") {
                viewModel.applySettings()
                viewModel.resetConversation()
                nextLineIndex = 0
                dismiss()
            }
            let lines = settingsStore.settings.script.lines
            if !lines.isEmpty {
                Picker("次に話す台詞", selection: nextLineBinding(count: lines.count)) {
                    ForEach(lines.indices, id: \.self) { index in
                        Text("\(index + 1). \(lines[index].prefix(20))").tag(index)
                    }
                    Text("（台本の終わり）").tag(lines.count)
                }
            }
        } header: {
            Text("テイク")
        }
    }

    private var scriptSection: some View {
        Section {
            TextEditor(text: $settingsStore.settings.scriptText)
                .font(.callout)
                .frame(minHeight: 200)
            Picker("台本を使い切ったら", selection: $settingsStore.settings.exhaustionPolicy) {
                Text("予備の台詞").tag(ScriptExhaustionPolicy.fallback)
                Text("最初に戻る").tag(ScriptExhaustionPolicy.loop)
            }
            TextField("予備の台詞", text: $settingsStore.settings.fallbackLine, axis: .vertical)
        } header: {
            Text("台本（\(settingsStore.settings.script.lines.count) 台詞）")
        } footer: {
            Text("台詞の区切りは「---」だけの行。「#」で始まる行はメモとして無視されます。入力された内容に関係なく、台詞を順番に返します。")
        }
    }

    private var rhythmSection: some View {
        Section {
            millisecondsSlider("考える時間", value: $settingsStore.settings.rhythm.thinkingDelay, range: 0...3000)
            millisecondsSlider("1 文字の間隔", value: $settingsStore.settings.rhythm.characterInterval, range: 10...200)
            millisecondsSlider("読点の間", value: $settingsStore.settings.rhythm.commaPause, range: 0...600)
            millisecondsSlider("句点の間", value: $settingsStore.settings.rhythm.sentencePause, range: 0...1500)
        } header: {
            Text("台本モードの文字送り")
        }
    }

    private var modelSection: some View {
        Section {
            Picker("モデル", selection: $settingsStore.settings.modelID) {
                ForEach(ModelCatalog.all) { spec in
                    Text(spec.displayName).tag(spec.id)
                }
            }
            LabeledContent("サイズ", value: "約 \(spec.approximateSizeMB) MB")
            LabeledContent("同梱", value: MLXEngine.bundledDirectory(for: spec) != nil ? "あり（オフライン可）" : "なし")
            LabeledContent("状態", value: viewModel.modelLoadState.label)
            Button("今すぐ読み込む") {
                viewModel.applySettings()
                Task { await viewModel.prepareModel() }
            }
            Button("ベンチマークを開く") {
                viewModel.applySettings()
                benchmarkModel = BenchmarkViewModel(engine: viewModel.generativeEngine())
                isShowingBenchmark = true
            }
        } header: {
            Text("AI 生成モードのモデル")
        } footer: {
            Text(spec.note)
        }
    }

    private var spec: ModelSpec { settingsStore.settings.model }

    private var personaSection: some View {
        Section {
            TextField("表示名", text: $settingsStore.settings.persona.name)
            TextEditor(text: $settingsStore.settings.persona.systemPrompt)
                .font(.callout)
                .frame(minHeight: 140)
            VStack(alignment: .leading) {
                Text(String(format: "温度 %.2f（低いほど毎回同じ返答に近づく）", settingsStore.settings.persona.temperature))
                Slider(value: $settingsStore.settings.persona.temperature, in: 0...1.5, step: 0.05)
            }
            Stepper(
                "最大トークン数 \(settingsStore.settings.persona.maxTokens)",
                value: $settingsStore.settings.persona.maxTokens,
                in: 32...512,
                step: 16
            )
            Toggle("シードを固定（42）", isOn: seedBinding)
        } header: {
            Text("作中 AI の人格（AI 生成モード）")
        } footer: {
            Text("人格を変えると会話の文脈はリセットされます。")
        }
    }

    // MARK: - Binding ヘルパー

    private func nextLineBinding(count: Int) -> Binding<Int> {
        Binding(
            get: { min(nextLineIndex, count) },
            set: { index in
                viewModel.applySettings()
                viewModel.scriptedEngine.jump(to: index)
                nextLineIndex = viewModel.scriptedEngine.cursor.nextIndex
            }
        )
    }

    private var seedBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.persona.seed != nil },
            set: { settingsStore.settings.persona.seed = $0 ? 42 : nil }
        )
    }

    private func millisecondsSlider(_ title: String, value: Binding<Duration>, range: ClosedRange<Double>) -> some View {
        let milliseconds = Binding<Double>(
            get: { value.wrappedValue.seconds * 1000 },
            set: { value.wrappedValue = .milliseconds(Int($0)) }
        )
        return VStack(alignment: .leading) {
            Text("\(title) \(Int(milliseconds.wrappedValue)) ms")
            Slider(value: milliseconds, in: range, step: 10)
        }
    }
}
