import AppKit

final class Settings {
  static let shared = Settings()
  private let defaults = UserDefaults.standard

  static let defaultShortcutKeyCode = 37
  static let defaultShortcutModifiers: UInt =
    NSEvent.ModifierFlags([.command, .shift]).rawValue
  static let defaultTopPhrase = "don't touch 🚫"
  static let defaultBottomPhrase = "only look 👀"
  static let defaultTopPhraseColorLight = NSColor.black
  static let defaultTopPhraseColorDark = NSColor.white
  static let defaultBottomPhraseColorLight = NSColor.black
  static let defaultBottomPhraseColorDark = NSColor.white
  static let defaultTopPadding: Double = 25
  static let defaultBottomPadding: Double = 20
  static let defaultTopPhraseFontSize: Double = 14
  static let defaultBottomPhraseFontSize: Double = 14
  static let defaultTextAlpha: Double = 0.9
  static let defaultSecurityLevel = "max"

  static func reset() {
    if let domain = Bundle.main.bundleIdentifier {
      UserDefaults.standard.removePersistentDomain(forName: domain)
    }
  }

  // Key code 37 = L, default shortcut ⌘⇧L
  var shortcutKeyCode: Int {
    get { defaults.object(forKey: "shortcutKeyCode") as? Int ?? Self.defaultShortcutKeyCode }
    set { defaults.set(newValue, forKey: "shortcutKeyCode") }
  }

  // Stored as Int (safe on 64-bit; modifier values are well within Int range)
  var shortcutModifiers: UInt {
    get {
      if let v = defaults.object(forKey: "shortcutModifiers") as? Int {
        return UInt(bitPattern: v)
      }
      return Self.defaultShortcutModifiers
    }
    set { defaults.set(Int(bitPattern: newValue), forKey: "shortcutModifiers") }
  }

  var topPhrase: String {
    get { defaults.string(forKey: "topPhrase") ?? Self.defaultTopPhrase }
    set { defaults.set(newValue, forKey: "topPhrase") }
  }

  var bottomPhrase: String {
    get { defaults.string(forKey: "bottomPhrase") ?? Self.defaultBottomPhrase }
    set { defaults.set(newValue, forKey: "bottomPhrase") }
  }

  var topPhraseColorLight: NSColor {
    get {
      if let data = defaults.data(forKey: "topPhraseColorLight"),
        let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
      {
        return color
      }
      // Fallback to old key
      if let data = defaults.data(forKey: "topPhraseColor"),
        let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
      {
        return color
      }
      return Self.defaultTopPhraseColorLight
    }
    set {
      let data = try? NSKeyedArchiver.archivedData(
        withRootObject: newValue, requiringSecureCoding: false)
      defaults.set(data, forKey: "topPhraseColorLight")
    }
  }

  var topPhraseColorDark: NSColor {
    get {
      guard let data = defaults.data(forKey: "topPhraseColorDark"),
        let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
      else { return Self.defaultTopPhraseColorDark }
      return color
    }
    set {
      let data = try? NSKeyedArchiver.archivedData(
        withRootObject: newValue, requiringSecureCoding: false)
      defaults.set(data, forKey: "topPhraseColorDark")
    }
  }

  var bottomPhraseColorLight: NSColor {
    get {
      if let data = defaults.data(forKey: "bottomPhraseColorLight"),
        let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
      {
        return color
      }
      // Fallback to old key
      if let data = defaults.data(forKey: "bottomPhraseColor"),
        let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
      {
        return color
      }
      return Self.defaultBottomPhraseColorLight
    }
    set {
      let data = try? NSKeyedArchiver.archivedData(
        withRootObject: newValue, requiringSecureCoding: false)
      defaults.set(data, forKey: "bottomPhraseColorLight")
    }
  }

  var bottomPhraseColorDark: NSColor {
    get {
      guard let data = defaults.data(forKey: "bottomPhraseColorDark"),
        let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
      else { return Self.defaultBottomPhraseColorDark }
      return color
    }
    set {
      let data = try? NSKeyedArchiver.archivedData(
        withRootObject: newValue, requiringSecureCoding: false)
      defaults.set(data, forKey: "bottomPhraseColorDark")
    }
  }

  var topPadding: Double {
    get { defaults.object(forKey: "topPadding") as? Double ?? Self.defaultTopPadding }
    set { defaults.set(newValue, forKey: "topPadding") }
  }

  var bottomPadding: Double {
    get { defaults.object(forKey: "bottomPadding") as? Double ?? Self.defaultBottomPadding }
    set { defaults.set(newValue, forKey: "bottomPadding") }
  }

  var topPhraseFontSize: Double {
    get { defaults.object(forKey: "topPhraseFontSize") as? Double ?? Self.defaultTopPhraseFontSize }
    set { defaults.set(newValue, forKey: "topPhraseFontSize") }
  }

  var bottomPhraseFontSize: Double {
    get { defaults.object(forKey: "bottomPhraseFontSize") as? Double ?? Self.defaultBottomPhraseFontSize }
    set { defaults.set(newValue, forKey: "bottomPhraseFontSize") }
  }

  var textAlpha: Double {
    get { defaults.object(forKey: "textAlpha") as? Double ?? Self.defaultTextAlpha }
    set { defaults.set(newValue, forKey: "textAlpha") }
  }

  // "max" = lock screen on ESC, "low" = just exit lock mode
  var securityLevel: String {
    get { defaults.string(forKey: "securityLevel") ?? Self.defaultSecurityLevel }
    set { defaults.set(newValue, forKey: "securityLevel") }
  }
}
