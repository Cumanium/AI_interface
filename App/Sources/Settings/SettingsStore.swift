import Foundation
import Observation
import PropCore

/// 設定を UserDefaults に JSON で保存・復元する。
@Observable
final class SettingsStore {
    private static let key = "PropSettings.v1"

    var settings: PropSettings {
        didSet { save() }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
            let decoded = try? JSONDecoder().decode(PropSettings.self, from: data)
        {
            settings = decoded
        } else {
            settings = PropSettings()
        }
    }

    func restoreDefaults() {
        settings = PropSettings()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
