import SwiftUI

@main
struct AIInterfaceApp: App {
    @State private var viewModel = ChatViewModel(settingsStore: SettingsStore())

    var body: some Scene {
        WindowGroup {
            ChatView(viewModel: viewModel)
                // 撮影中に画面が消えないようにする。
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        }
    }
}
