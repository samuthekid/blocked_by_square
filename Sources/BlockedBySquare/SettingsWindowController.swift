import AppKit

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private var shortcutField: ShortcutField!
    private var topPhraseField: NSTextField!
    private var bottomPhraseField: NSTextField!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 310),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "BlockedBySquare Settings"
        window.center()
        self.init(window: window)
        window.delegate = self
        buildUI()
    }

    private func buildUI() {
        guard let cv = window?.contentView else { return }

        // ── Shortcut card ────────────────────────────────────────────────────────
        cv.addSubview(makeCard(frame: NSRect(x: 16, y: 220, width: 468, height: 76)))

        addLabel("Activation shortcut:", to: cv,
                 frame: NSRect(x: 28, y: 266, width: 130, height: 24))

        shortcutField = ShortcutField(frame: NSRect(x: 164, y: 266, width: 176, height: 24))
        shortcutField.isBordered = true
        shortcutField.bezelStyle = .roundedBezel
        shortcutField.alignment = .center
        shortcutField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        let s = Settings.shared
        shortcutField.stringValue = formatShortcut(
            keyCode: s.shortcutKeyCode,
            modifiers: NSEvent.ModifierFlags(rawValue: s.shortcutModifiers)
        )
        shortcutField.onShortcutChanged = { keyCode, mods in
            Settings.shared.shortcutKeyCode = keyCode
            Settings.shared.shortcutModifiers = mods.rawValue
            (NSApp.delegate as? AppDelegate)?.updateGlobalShortcut()
        }
        cv.addSubview(shortcutField)

        cv.addSubview(makeHintLabel(
            "Click the field, then press your shortcut. ESC cancels.",
            frame: NSRect(x: 164, y: 244, width: 308, height: 16)
        ))

        // ── Text card ────────────────────────────────────────────────────────────
        cv.addSubview(makeCard(frame: NSRect(x: 16, y: 76, width: 468, height: 130)))

        if let img = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: nil) {
            let icon = NSImageView(frame: NSRect(x: 28, y: 180, width: 14, height: 14))
            icon.image = img
            icon.contentTintColor = .secondaryLabelColor
            cv.addSubview(icon)
        }
        let sectionLabel = NSTextField(labelWithString: "TEXT IN THE SQUARE")
        sectionLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        sectionLabel.textColor = .secondaryLabelColor
        sectionLabel.frame = NSRect(x: 46, y: 180, width: 300, height: 14)
        cv.addSubview(sectionLabel)

        cv.addSubview(makeHintLabel(
            "These phrases appear inside the glass square around the cursor.",
            frame: NSRect(x: 28, y: 160, width: 440, height: 14)
        ))

        addLabel("Top phrase:", to: cv, frame: NSRect(x: 28, y: 122, width: 130, height: 24))
        topPhraseField = makeTextField(frame: NSRect(x: 164, y: 122, width: 244, height: 24),
                                       placeholder: "Optional")
        topPhraseField.stringValue = Settings.shared.topPhrase
        cv.addSubview(topPhraseField)
        cv.addSubview(makeEmojiButton(tag: 0, frame: NSRect(x: 412, y: 123, width: 52, height: 22)))

        addLabel("Bottom phrase:", to: cv, frame: NSRect(x: 28, y: 90, width: 130, height: 24))
        bottomPhraseField = makeTextField(frame: NSRect(x: 164, y: 90, width: 244, height: 24),
                                          placeholder: "Optional")
        bottomPhraseField.stringValue = Settings.shared.bottomPhrase
        cv.addSubview(bottomPhraseField)
        cv.addSubview(makeEmojiButton(tag: 1, frame: NSRect(x: 412, y: 91, width: 52, height: 22)))

        // ── Bottom bar ───────────────────────────────────────────────────────────
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: 0, y: 68, width: 500, height: 1)
        cv.addSubview(sep)

        cv.addSubview(makeHintLabel(
            "ESC always locks the screen when lock mode is active.",
            frame: NSRect(x: 20, y: 26, width: 380, height: 14)
        ))

        let saveBtn = NSButton(title: "Save", target: self, action: #selector(save))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        saveBtn.frame = NSRect(x: 414, y: 18, width: 70, height: 32)
        cv.addSubview(saveBtn)
    }

    @objc private func save() {
        commitPhrases()
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        commitPhrases()
    }

    private func commitPhrases() {
        Settings.shared.topPhrase    = topPhraseField.stringValue
        Settings.shared.bottomPhrase = bottomPhraseField.stringValue
        (NSApp.delegate as? AppDelegate)?.updateOverlayPhrases()
    }

    @objc private func openEmojiPicker(_ sender: NSButton) {
        let field = sender.tag == 0 ? topPhraseField! : bottomPhraseField!
        window?.makeFirstResponder(field)
        NSApp.orderFrontCharacterPalette(sender)
    }

    // MARK: - Helpers

    private func makeCard(frame: NSRect) -> NSBox {
        let box = NSBox(frame: frame)
        box.boxType = .custom
        box.fillColor = NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1, alpha: 0.07)
                : NSColor(white: 0, alpha: 0.04)
        })
        box.borderColor = NSColor.separatorColor
        box.cornerRadius = 10
        box.borderWidth = 0.5
        return box
    }

    private func makeEmojiButton(tag: Int, frame: NSRect) -> NSButton {
        let btn = NSButton(frame: frame)
        let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        btn.image = NSImage(systemSymbolName: "face.smiling",
                            accessibilityDescription: "Open emoji picker")?
            .withSymbolConfiguration(cfg)
        btn.imagePosition = .imageOnly
        btn.bezelStyle = .rounded
        btn.tag = tag
        btn.action = #selector(openEmojiPicker(_:))
        btn.target = self
        btn.toolTip = "Open emoji & symbol picker"
        return btn
    }

    private func makeHintLabel(_ text: String, frame: NSRect) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .tertiaryLabelColor
        label.frame = frame
        return label
    }

    @discardableResult
    private func addLabel(_ text: String, to view: NSView, frame: NSRect) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        label.frame = frame
        view.addSubview(label)
        return label
    }

    private func makeTextField(frame: NSRect, placeholder: String) -> NSTextField {
        let field = NSTextField(frame: frame)
        field.placeholderString = placeholder
        field.bezelStyle = .roundedBezel
        field.isBordered = true
        return field
    }
}
