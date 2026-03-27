import Foundation

enum CountdownPreferences {
    static let countdownEnabled = "countdownEnabled"
    static let overlayEnabled = "overlayEnabled"
    static let menuBarFlashEnabled = "menuBarFlashEnabled"
    static let countdownSoundEnabled = "countdownSoundEnabled"

    static func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil {
            return defaultValue
        }

        return UserDefaults.standard.bool(forKey: key)
    }

    static func set(_ value: Bool, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
