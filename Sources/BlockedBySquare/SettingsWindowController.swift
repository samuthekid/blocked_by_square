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
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 340),
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

        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 16
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(mainStack)

        // ── Shortcut card ──
        do {
            let card = makeCard(frame: .zero)
            card.translatesAutoresizingMaskIntoConstraints = false

            let label = NSTextField(labelWithString: "Activation shortcut")
            label.font = .systemFont(ofSize: 13)

            shortcutField = ShortcutField(frame: .zero)
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
            shortcutField.translatesAutoresizingMaskIntoConstraints = false
            shortcutField.widthAnchor.constraint(equalToConstant: 162).isActive = true

            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

            let row = NSStackView(views: [label, spacer, shortcutField])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.edgeInsets = NSEdgeInsets(top: 16, left: 12, bottom: 12, right: 12)
            row.translatesAutoresizingMaskIntoConstraints = false

            card.addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: card.topAnchor),
                row.bottomAnchor.constraint(equalTo: card.bottomAnchor),
                row.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            ])

            mainStack.addArrangedSubview(card)
            card.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
        }

        // ── Launch at Login card ──
        do {
            let card = makeCard(frame: .zero)
            card.translatesAutoresizingMaskIntoConstraints = false

            let label = NSTextField(labelWithString: "Open at login")
            label.font = .systemFont(ofSize: 13)

            let toggleHost = NSHostingView(rootView: LaunchToggle())
            toggleHost.translatesAutoresizingMaskIntoConstraints = false

            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

            let row = NSStackView(views: [label, spacer, toggleHost])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.edgeInsets = NSEdgeInsets(top: 16, left: 12, bottom: 12, right: 12)
            row.translatesAutoresizingMaskIntoConstraints = false

            card.addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: card.topAnchor),
                row.bottomAnchor.constraint(equalTo: card.bottomAnchor),
                row.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            ])

            mainStack.addArrangedSubview(card)
            card.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
        }

        // ── Text card ──
        do {
            let card = makeCard(frame: .zero)
            card.translatesAutoresizingMaskIntoConstraints = false

            // Header row
            let headerIcon = NSImageView()
            headerIcon.image = NSImage(systemSymbolName: "text.bubble",
                                       accessibilityDescription: nil)
            headerIcon.contentTintColor = .secondaryLabelColor
            headerIcon.translatesAutoresizingMaskIntoConstraints = false
            headerIcon.widthAnchor.constraint(equalToConstant: 14).isActive = true
            headerIcon.heightAnchor.constraint(equalToConstant: 14).isActive = true

            let sectionLabel = NSTextField(labelWithString: "TEXT IN THE SQUARE")
            sectionLabel.font = .systemFont(ofSize: 10, weight: .semibold)
            sectionLabel.textColor = .secondaryLabelColor

            let headerRow = NSStackView(views: [headerIcon, sectionLabel])
            headerRow.spacing = 4
            headerRow.alignment = .centerY

            // Hint
            let hint = NSTextField(labelWithString:
                "These phrases appear inside the glass square around the cursor.")
            hint.font = .systemFont(ofSize: 11)
            hint.textColor = .tertiaryLabelColor

            // ── Top phrase row ──
            let topLabel = NSTextField(labelWithString: "Top phrase:")
            topLabel.alignment = .right
            topLabel.translatesAutoresizingMaskIntoConstraints = false
            topLabel.widthAnchor.constraint(equalToConstant: 130).isActive = true

            topPhraseField = NSTextField()
            topPhraseField.placeholderString = "Optional"
            topPhraseField.bezelStyle = .roundedBezel
            topPhraseField.isBordered = true
            topPhraseField.stringValue = Settings.shared.topPhrase
            topPhraseField.translatesAutoresizingMaskIntoConstraints = false

            topColorWell = NSColorWell()
            if #available(macOS 13.0, *) { topColorWell.colorWellStyle = .minimal }
            topColorWell.color = Settings.shared.topPhraseColor
            topColorWell.tag = 0
            topColorWell.target = self
            topColorWell.action = #selector(colorWellChanged(_:))
            topColorWell.toolTip = "Top phrase color"
            topColorWell.translatesAutoresizingMaskIntoConstraints = false
            topColorWell.widthAnchor.constraint(equalToConstant: 40).isActive = true

            let topEmoji = NSButton()
            let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            topEmoji.image = NSImage(systemSymbolName: "face.smiling",
                                     accessibilityDescription: "Open emoji picker")?
                .withSymbolConfiguration(cfg)
            topEmoji.imagePosition = .imageOnly
            topEmoji.bezelStyle = .rounded
            topEmoji.tag = 0
            topEmoji.action = #selector(openEmojiPicker(_:))
            topEmoji.target = self
            topEmoji.toolTip = "Open emoji & symbol picker"
            topEmoji.translatesAutoresizingMaskIntoConstraints = false
            topEmoji.widthAnchor.constraint(equalToConstant: 52).isActive = true

            let topRow = NSStackView(views: [topLabel, topPhraseField, topColorWell, topEmoji])
            topRow.spacing = 8
            topRow.alignment = .centerY

            // ── Bottom phrase row ──
            let bottomLabel = NSTextField(labelWithString: "Bottom phrase:")
            bottomLabel.alignment = .right
            bottomLabel.translatesAutoresizingMaskIntoConstraints = false
            bottomLabel.widthAnchor.constraint(equalToConstant: 130).isActive = true

            bottomPhraseField = NSTextField()
            bottomPhraseField.placeholderString = "Optional"
            bottomPhraseField.bezelStyle = .roundedBezel
            bottomPhraseField.isBordered = true
            bottomPhraseField.stringValue = Settings.shared.bottomPhrase
            bottomPhraseField.translatesAutoresizingMaskIntoConstraints = false

            bottomColorWell = NSColorWell()
            if #available(macOS 13.0, *) { bottomColorWell.colorWellStyle = .minimal }
            bottomColorWell.color = Settings.shared.bottomPhraseColor
            bottomColorWell.tag = 1
            bottomColorWell.target = self
            bottomColorWell.action = #selector(colorWellChanged(_:))
            bottomColorWell.toolTip = "Bottom phrase color"
            bottomColorWell.translatesAutoresizingMaskIntoConstraints = false
            bottomColorWell.widthAnchor.constraint(equalToConstant: 40).isActive = true

            let bottomEmoji = NSButton()
            bottomEmoji.image = NSImage(systemSymbolName: "face.smiling",
                                        accessibilityDescription: "Open emoji picker")?
                .withSymbolConfiguration(cfg)
            bottomEmoji.imagePosition = .imageOnly
            bottomEmoji.bezelStyle = .rounded
            bottomEmoji.tag = 1
            bottomEmoji.action = #selector(openEmojiPicker(_:))
            bottomEmoji.target = self
            bottomEmoji.toolTip = "Open emoji & symbol picker"
            bottomEmoji.translatesAutoresizingMaskIntoConstraints = false
            bottomEmoji.widthAnchor.constraint(equalToConstant: 52).isActive = true

            let bottomRow = NSStackView(views: [bottomLabel, bottomPhraseField, bottomColorWell, bottomEmoji])
            bottomRow.spacing = 8
            bottomRow.alignment = .centerY

            // Assemble text card
            let inset: CGFloat = 12
            headerRow.translatesAutoresizingMaskIntoConstraints = false
            hint.translatesAutoresizingMaskIntoConstraints = false
            topRow.translatesAutoresizingMaskIntoConstraints = false
            bottomRow.translatesAutoresizingMaskIntoConstraints = false

            card.addSubview(headerRow)
            card.addSubview(hint)
            card.addSubview(topRow)
            card.addSubview(bottomRow)
            NSLayoutConstraint.activate([
                headerRow.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
                headerRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: inset),
                headerRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -inset),

                hint.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 8),
                hint.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: inset),
                hint.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -inset),

                topRow.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 8),
                topRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: inset),
                topRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -inset),

                bottomRow.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 8),
                bottomRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: inset),
                bottomRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -inset),
                card.bottomAnchor.constraint(equalTo: bottomRow.bottomAnchor, constant: 12),
            ])

            mainStack.addArrangedSubview(card)
            card.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
        }

        // ── Separator and bottom bar ──
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(sep)

        let hintLabel = NSTextField(labelWithString: "ESC always locks the screen when lock mode is active.")
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(hintLabel)

        let saveBtn = NSButton(title: "Save", target: self, action: #selector(save))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        saveBtn.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(saveBtn)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: cv.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -16),

            sep.topAnchor.constraint(equalTo: mainStack.bottomAnchor, constant: 16),
            sep.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: cv.trailingAnchor),

            hintLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            hintLabel.centerYAnchor.constraint(equalTo: saveBtn.centerYAnchor),

            saveBtn.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -16),
            saveBtn.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -18),
        ])

        // Live preview updates as the user types
        NotificationCenter.default.addObserver(
            self, selector: #selector(phraseFieldChanged),
            name: NSControl.textDidChangeNotification, object: topPhraseField)
        NotificationCenter.default.addObserver(
            self, selector: #selector(phraseFieldChanged),
            name: NSControl.textDidChangeNotification, object: bottomPhraseField)
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
}

// MARK: - Preview Window

private class PreviewWindow: NSWindow {
    private let overlayView: OverlayView
    private static let size: CGFloat = 220

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
