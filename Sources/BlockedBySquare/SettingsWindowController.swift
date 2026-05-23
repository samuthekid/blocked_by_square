import AppKit

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private var shortcutField: ShortcutField!
    private var topPhraseField: NSTextField!
    private var bottomPhraseField: NSTextField!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 290),
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

        let labelW: CGFloat = 150
        let fieldX: CGFloat = 168
        let fieldW: CGFloat = 244
        let rowH:   CGFloat = 26

        // ── Activation shortcut ──────────────────────────────────────────────
        addLabel("Activation shortcut:", to: cv, frame: NSRect(x: 20, y: 228, width: labelW, height: rowH))

        shortcutField = ShortcutField(frame: NSRect(x: fieldX, y: 228, width: 160, height: rowH))
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

        let hint = NSTextField(labelWithString: "Click the field, then press your shortcut. ESC cancels.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: fieldX, y: 208, width: 260, height: 16)
        cv.addSubview(hint)

        // ── Divider ──────────────────────────────────────────────────────────
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: 20, y: 192, width: 400, height: 1)
        cv.addSubview(sep)

        // ── Text in the square ───────────────────────────────────────────────
        let sectionLabel = NSTextField(labelWithString: "TEXT IN THE SQUARE")
        sectionLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        sectionLabel.textColor = .secondaryLabelColor
        sectionLabel.frame = NSRect(x: 20, y: 174, width: 400, height: 16)
        cv.addSubview(sectionLabel)

        let escNote = NSTextField(labelWithString: "These phrases appear inside the glass square around the cursor.")
        escNote.font = .systemFont(ofSize: 11)
        escNote.textColor = .secondaryLabelColor
        escNote.frame = NSRect(x: 20, y: 156, width: 400, height: 16)
        cv.addSubview(escNote)

        addLabel("Top phrase:", to: cv, frame: NSRect(x: 20, y: 124, width: labelW, height: rowH))
        topPhraseField = makeTextField(frame: NSRect(x: fieldX, y: 124, width: fieldW, height: rowH), placeholder: "Optional")
        topPhraseField.stringValue = Settings.shared.topPhrase
        cv.addSubview(topPhraseField)

        addLabel("Bottom phrase:", to: cv, frame: NSRect(x: 20, y: 84, width: labelW, height: rowH))
        bottomPhraseField = makeTextField(frame: NSRect(x: fieldX, y: 84, width: fieldW, height: rowH), placeholder: "Optional")
        bottomPhraseField.stringValue = Settings.shared.bottomPhrase
        cv.addSubview(bottomPhraseField)

        // ── Divider ──────────────────────────────────────────────────────────
        let sep2 = NSBox()
        sep2.boxType = .separator
        sep2.frame = NSRect(x: 20, y: 64, width: 400, height: 1)
        cv.addSubview(sep2)

        // ── ESC note + Save ──────────────────────────────────────────────────
        let escInfo = NSTextField(labelWithString: "ESC always locks the screen when lock mode is active.")
        escInfo.font = .systemFont(ofSize: 11)
        escInfo.textColor = .secondaryLabelColor
        escInfo.frame = NSRect(x: 20, y: 28, width: 310, height: 16)
        cv.addSubview(escInfo)

        let saveBtn = NSButton(title: "Save", target: self, action: #selector(save))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        saveBtn.frame = NSRect(x: 344, y: 20, width: 76, height: 28)
        cv.addSubview(saveBtn)
    }

    @objc private func save() {
        commitPhrases()
        window?.close()
    }

    // Also commit when the window is closed via the × button
    func windowWillClose(_ notification: Notification) {
        commitPhrases()
    }

    private func commitPhrases() {
        Settings.shared.topPhrase    = topPhraseField.stringValue
        Settings.shared.bottomPhrase = bottomPhraseField.stringValue
        (NSApp.delegate as? AppDelegate)?.updateOverlayPhrases()
    }

    // MARK: - Helpers

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
