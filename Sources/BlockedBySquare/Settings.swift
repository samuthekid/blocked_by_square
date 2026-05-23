import AppKit

final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    // Key code 37 = L, default shortcut ⌘⇧L
    var shortcutKeyCode: Int {
        get { defaults.object(forKey: "shortcutKeyCode") as? Int ?? 37 }
        set { defaults.set(newValue, forKey: "shortcutKeyCode") }
    }

    // Stored as Int (safe on 64-bit; modifier values are well within Int range)
    var shortcutModifiers: UInt {
        get {
            if let v = defaults.object(forKey: "shortcutModifiers") as? Int {
                return UInt(bitPattern: v)
            }
            return NSEvent.ModifierFlags([.command, .shift]).rawValue
        }
        set { defaults.set(Int(bitPattern: newValue), forKey: "shortcutModifiers") }
    }

    var topPhrase: String {
        get { defaults.string(forKey: "topPhrase") ?? "" }
        set { defaults.set(newValue, forKey: "topPhrase") }
    }

    var bottomPhrase: String {
        get { defaults.string(forKey: "bottomPhrase") ?? "" }
        set { defaults.set(newValue, forKey: "bottomPhrase") }
    }
}
