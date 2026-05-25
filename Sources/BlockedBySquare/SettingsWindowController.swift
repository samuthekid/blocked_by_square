import AppKit
import ServiceManagement
import SwiftUI

private struct LaunchToggle: View {
    @State private var isOn: Bool

    init() {
        _isOn = State(initialValue: SMAppService.mainApp.status == .enabled)
    }

    var body: some View {
        Toggle("", isOn: $isOn)
            .toggleStyle(.switch)
            .labelsHidden()
            .onChange(of: isOn) { newValue in
                if newValue {
                    try? SMAppService.mainApp.register()
                } else {
                    try? SMAppService.mainApp.unregister()
                }
            }
    }
}

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private var shortcutField: ShortcutField!
    private var topPhraseField: NSTextField!
    private var bottomPhraseField: NSTextField!
    private var topColorWell: NSColorWell!
    private var bottomColorWell: NSColorWell!
    private var previewWindow: PreviewWindow?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
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

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        showPreview()
    }

    private func showPreview() {
        guard let settingsWindow = window else { return }

        let pw: PreviewWindow
        if let existing = previewWindow {
            pw = existing
        } else {
            pw = PreviewWindow()
            previewWindow = pw
        }

        let gap: CGFloat = 20
        let origin = NSPoint(
            x: settingsWindow.frame.midX - pw.frame.width / 2,
            y: settingsWindow.frame.minY - gap - pw.frame.height
        )
        pw.setFrameOrigin(origin)

        if pw.parent == nil {
            settingsWindow.addChildWindow(pw, ordered: .below)
        }
    }

    private func buildUI() {
        guard let cv = window?.contentView else { return }

        // ── Shortcut card ────────────────────────────────────────────────────────
        cv.addSubview(makeCard(frame: NSRect(x: 16, y: 360, width: 468, height: 60)))

        let shortcutLabel = NSTextField(labelWithString: "Activation shortcut")
        shortcutLabel.font = .systemFont(ofSize: 13)
        shortcutLabel.frame = NSRect(x: 28, y: 380, width: 220, height: 20)
        cv.addSubview(shortcutLabel)

        shortcutField = ShortcutField(frame: NSRect(x: 306, y: 378, width: 162, height: 24))
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

        // ── Launch at Login card ─────────────────────────────────────────────────
        cv.addSubview(makeCard(frame: NSRect(x: 16, y: 290, width: 468, height: 60)))

        let loginLabel = NSTextField(labelWithString: "Open at login")
        loginLabel.font = .systemFont(ofSize: 13)
        loginLabel.frame = NSRect(x: 28, y: 309, width: 220, height: 22)
        cv.addSubview(loginLabel)

        let toggleHost = NSHostingView(rootView: LaunchToggle())
        toggleHost.frame = NSRect(x: 418, y: 304, width: 50, height: 31)
        cv.addSubview(toggleHost)

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
        topPhraseField = makeTextField(frame: NSRect(x: 164, y: 122, width: 196, height: 24),
                                       placeholder: "Optional")
        topPhraseField.stringValue = Settings.shared.topPhrase
        cv.addSubview(topPhraseField)
        topColorWell = makeColorWell(tag: 0, color: Settings.shared.topPhraseColor,
                                     frame: NSRect(x: 364, y: 122, width: 40, height: 24))
        cv.addSubview(topColorWell)
        cv.addSubview(makeEmojiButton(tag: 0, frame: NSRect(x: 408, y: 123, width: 52, height: 22)))

        addLabel("Bottom phrase:", to: cv, frame: NSRect(x: 28, y: 90, width: 130, height: 24))
        bottomPhraseField = makeTextField(frame: NSRect(x: 164, y: 90, width: 196, height: 24),
                                          placeholder: "Optional")
        bottomPhraseField.stringValue = Settings.shared.bottomPhrase
        cv.addSubview(bottomPhraseField)
        bottomColorWell = makeColorWell(tag: 1, color: Settings.shared.bottomPhraseColor,
                                        frame: NSRect(x: 364, y: 90, width: 40, height: 24))
        cv.addSubview(bottomColorWell)
        cv.addSubview(makeEmojiButton(tag: 1, frame: NSRect(x: 408, y: 91, width: 52, height: 22)))

        // Live preview updates as the user types
        NotificationCenter.default.addObserver(
            self, selector: #selector(phraseFieldChanged),
            name: NSControl.textDidChangeNotification, object: topPhraseField)
        NotificationCenter.default.addObserver(
            self, selector: #selector(phraseFieldChanged),
            name: NSControl.textDidChangeNotification, object: bottomPhraseField)

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
        topColorWell.deactivate()
        bottomColorWell.deactivate()
        commitPhrases()
        if let pw = previewWindow {
            window?.removeChildWindow(pw)
            pw.close()
            previewWindow = nil
        }
    }

    private func commitPhrases() {
        Settings.shared.topPhrase    = topPhraseField.stringValue
        Settings.shared.bottomPhrase = bottomPhraseField.stringValue
        (NSApp.delegate as? AppDelegate)?.updateOverlayPhrases()
    }

    @objc private func phraseFieldChanged(_ notification: Notification) {
        previewWindow?.updatePhrases(top: topPhraseField.stringValue,
                                     bottom: bottomPhraseField.stringValue)
    }

    @objc private func colorWellChanged(_ sender: NSColorWell) {
        if sender.tag == 0 {
            Settings.shared.topPhraseColor = sender.color
        } else {
            Settings.shared.bottomPhraseColor = sender.color
        }
        (NSApp.delegate as? AppDelegate)?.updateOverlayTextColors()
        previewWindow?.updateTextColors(top: Settings.shared.topPhraseColor,
                                        bottom: Settings.shared.bottomPhraseColor)
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

    private func makeColorWell(tag: Int, color: NSColor, frame: NSRect) -> NSColorWell {
        let well = NSColorWell(frame: frame)
        if #available(macOS 13.0, *) { well.colorWellStyle = .minimal }
        well.color  = color
        well.tag    = tag
        well.target = self
        well.action = #selector(colorWellChanged(_:))
        well.toolTip = tag == 0 ? "Top phrase color" : "Bottom phrase color"
        return well
    }

    private func makeTextField(frame: NSRect, placeholder: String) -> NSTextField {
        let field = NSTextField(frame: frame)
        field.placeholderString = placeholder
        field.bezelStyle = .roundedBezel
        field.isBordered = true
        return field
    }
}

// MARK: - Preview Window

private class PreviewWindow: NSWindow {
    private let overlayView: OverlayView
    private static let size: CGFloat = 260

    init() {
        let sz = Self.size
        overlayView = OverlayView(frame: NSRect(x: 0, y: 0, width: sz, height: sz))
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: sz, height: sz),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        backgroundColor     = .clear
        isOpaque            = false
        hasShadow           = false
        ignoresMouseEvents  = true
        isReleasedWhenClosed = false

        contentView = overlayView

        // Show the square centred and seed it with current settings
        overlayView.showSquare(at: CGPoint(x: sz / 2, y: sz / 2))
        overlayView.updatePhrases(top: Settings.shared.topPhrase,
                                  bottom: Settings.shared.bottomPhrase)
        overlayView.updateTextColors(top: Settings.shared.topPhraseColor,
                                     bottom: Settings.shared.bottomPhraseColor)
    }

    func updatePhrases(top: String, bottom: String) {
        overlayView.updatePhrases(top: top, bottom: bottom)
    }

    func updateTextColors(top: NSColor, bottom: NSColor) {
        overlayView.updateTextColors(top: top, bottom: bottom)
    }
}
