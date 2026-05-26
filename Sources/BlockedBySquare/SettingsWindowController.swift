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

class PhraseField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command),
           event.modifierFlags.contains(.control),
           event.charactersIgnoringModifiers == " " {
            NSApp.orderFrontCharacterPalette(self)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private var shortcutField: ShortcutField!
    private var topPhraseField: PhraseField!
    private var bottomPhraseField: PhraseField!
    private var topColorWellLight: NSColorWell!
    private var topColorWellDark: NSColorWell!
    private var bottomColorWellLight: NSColorWell!
    private var bottomColorWellDark: NSColorWell!
    private var topPaddingField: NSTextField!
    private var topPaddingStepper: NSStepper!
    private var bottomPaddingField: NSTextField!
    private var bottomPaddingStepper: NSStepper!
    private var previewWindow: PreviewWindow?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 500),
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

        // ── Security level card ──
        do {
            let card = makeCard(frame: .zero)
            card.translatesAutoresizingMaskIntoConstraints = false

            let label = NSTextField(labelWithString: "Security level")
            label.font = .systemFont(ofSize: 13)

            let hint = NSTextField(labelWithString:
                "Max: ESC locks the screen. Low: ESC just exits lock mode.")
            hint.font = .systemFont(ofSize: 11)
            hint.textColor = .tertiaryLabelColor

            let leftStack = NSStackView(views: [label, hint])
            leftStack.orientation = .vertical
            leftStack.spacing = 2
            leftStack.alignment = .leading

            let popup = NSPopUpButton(frame: .zero, pullsDown: false)
            popup.addItems(withTitles: ["Max", "Low"])
            popup.selectItem(withTitle: Settings.shared.securityLevel == "low" ? "Low" : "Max")
            popup.target = self
            popup.action = #selector(securityLevelChanged(_:))
            popup.setContentHuggingPriority(.required, for: .horizontal)
            popup.translatesAutoresizingMaskIntoConstraints = false

            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

            let hStack = NSStackView(views: [leftStack, spacer, popup])
            hStack.orientation = .horizontal
            hStack.alignment = .centerY
            hStack.edgeInsets = NSEdgeInsets(top: 16, left: 12, bottom: 12, right: 12)
            hStack.translatesAutoresizingMaskIntoConstraints = false

            card.addSubview(hStack)
            NSLayoutConstraint.activate([
                hStack.topAnchor.constraint(equalTo: card.topAnchor),
                hStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
                hStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                hStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
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

            topPhraseField = PhraseField()
            topPhraseField.placeholderString = "Optional"
            topPhraseField.bezelStyle = .roundedBezel
            topPhraseField.isBordered = true
            topPhraseField.stringValue = Settings.shared.topPhrase
            topPhraseField.translatesAutoresizingMaskIntoConstraints = false

            topColorWellLight = NSColorWell()
            if #available(macOS 13.0, *) { topColorWellLight.colorWellStyle = .minimal }
            topColorWellLight.color = Settings.shared.topPhraseColorLight
            topColorWellLight.tag = 0
            topColorWellLight.target = self
            topColorWellLight.action = #selector(colorWellChanged(_:))
            topColorWellLight.toolTip = "Light mode color"
            topColorWellLight.translatesAutoresizingMaskIntoConstraints = false
            topColorWellLight.widthAnchor.constraint(equalToConstant: 32).isActive = true

            let topLightStack = makeColorWellStack(well: topColorWellLight, label: "Light")

            topColorWellDark = NSColorWell()
            if #available(macOS 13.0, *) { topColorWellDark.colorWellStyle = .minimal }
            topColorWellDark.color = Settings.shared.topPhraseColorDark
            topColorWellDark.tag = 2
            topColorWellDark.target = self
            topColorWellDark.action = #selector(colorWellChanged(_:))
            topColorWellDark.toolTip = "Dark mode color"
            topColorWellDark.translatesAutoresizingMaskIntoConstraints = false
            topColorWellDark.widthAnchor.constraint(equalToConstant: 32).isActive = true

            let topDarkStack = makeColorWellStack(well: topColorWellDark, label: "Dark")

            let topRow = NSStackView(views: [topLabel, topPhraseField, topLightStack, topDarkStack])
            topRow.spacing = 8
            topRow.alignment = .centerY

            // ── Bottom phrase row ──
            let bottomLabel = NSTextField(labelWithString: "Bottom phrase:")
            bottomLabel.alignment = .right
            bottomLabel.translatesAutoresizingMaskIntoConstraints = false
            bottomLabel.widthAnchor.constraint(equalToConstant: 130).isActive = true

            bottomPhraseField = PhraseField()
            bottomPhraseField.placeholderString = "Optional"
            bottomPhraseField.bezelStyle = .roundedBezel
            bottomPhraseField.isBordered = true
            bottomPhraseField.stringValue = Settings.shared.bottomPhrase
            bottomPhraseField.translatesAutoresizingMaskIntoConstraints = false

            bottomColorWellLight = NSColorWell()
            if #available(macOS 13.0, *) { bottomColorWellLight.colorWellStyle = .minimal }
            bottomColorWellLight.color = Settings.shared.bottomPhraseColorLight
            bottomColorWellLight.tag = 1
            bottomColorWellLight.target = self
            bottomColorWellLight.action = #selector(colorWellChanged(_:))
            bottomColorWellLight.toolTip = "Light mode color"
            bottomColorWellLight.translatesAutoresizingMaskIntoConstraints = false
            bottomColorWellLight.widthAnchor.constraint(equalToConstant: 32).isActive = true

            let bottomLightStack = makeColorWellStack(well: bottomColorWellLight, label: "Light")

            bottomColorWellDark = NSColorWell()
            if #available(macOS 13.0, *) { bottomColorWellDark.colorWellStyle = .minimal }
            bottomColorWellDark.color = Settings.shared.bottomPhraseColorDark
            bottomColorWellDark.tag = 3
            bottomColorWellDark.target = self
            bottomColorWellDark.action = #selector(colorWellChanged(_:))
            bottomColorWellDark.toolTip = "Dark mode color"
            bottomColorWellDark.translatesAutoresizingMaskIntoConstraints = false
            bottomColorWellDark.widthAnchor.constraint(equalToConstant: 32).isActive = true

            let bottomDarkStack = makeColorWellStack(well: bottomColorWellDark, label: "Dark")

            let bottomRow = NSStackView(views: [bottomLabel, bottomPhraseField, bottomLightStack, bottomDarkStack])
            bottomRow.spacing = 8
            bottomRow.alignment = .centerY

            // ── Top padding row ──
            let topPaddingLabel = NSTextField(labelWithString: "Top padding:")
            topPaddingLabel.alignment = .right
            topPaddingLabel.translatesAutoresizingMaskIntoConstraints = false
            topPaddingLabel.widthAnchor.constraint(equalToConstant: 130).isActive = true

            topPaddingField = NSTextField()
            let padFmt = NumberFormatter()
            padFmt.minimum = 0
            padFmt.maximum = 100
            topPaddingField.formatter = padFmt
            topPaddingField.bezelStyle = .roundedBezel
            topPaddingField.isBordered = true
            topPaddingField.stringValue = "\(Int(Settings.shared.topPadding))"
            topPaddingField.translatesAutoresizingMaskIntoConstraints = false
            topPaddingField.widthAnchor.constraint(equalToConstant: 60).isActive = true

            topPaddingStepper = NSStepper()
            topPaddingStepper.minValue = 0
            topPaddingStepper.maxValue = 100
            topPaddingStepper.integerValue = Int(Settings.shared.topPadding)
            topPaddingStepper.tag = 0
            topPaddingStepper.target = self
            topPaddingStepper.action = #selector(paddingStepperChanged(_:))
            topPaddingStepper.translatesAutoresizingMaskIntoConstraints = false

            let topPadReset = NSButton(title: "Reset", target: self, action: #selector(resetTopPadding))
            topPadReset.bezelStyle = .rounded
            topPadReset.font = .systemFont(ofSize: 11)
            topPadReset.translatesAutoresizingMaskIntoConstraints = false

            let topPaddingRow = NSStackView(views: [topPaddingLabel, topPaddingField, topPaddingStepper, topPadReset])
            topPaddingRow.spacing = 8
            topPaddingRow.alignment = .centerY
            topPaddingRow.translatesAutoresizingMaskIntoConstraints = false

            // ── Bottom padding row ──
            let bottomPaddingLabel = NSTextField(labelWithString: "Bottom padding:")
            bottomPaddingLabel.alignment = .right
            bottomPaddingLabel.translatesAutoresizingMaskIntoConstraints = false
            bottomPaddingLabel.widthAnchor.constraint(equalToConstant: 130).isActive = true

            bottomPaddingField = NSTextField()
            let btmFmt = NumberFormatter()
            btmFmt.minimum = 0
            btmFmt.maximum = 100
            bottomPaddingField.formatter = btmFmt
            bottomPaddingField.bezelStyle = .roundedBezel
            bottomPaddingField.isBordered = true
            bottomPaddingField.stringValue = "\(Int(Settings.shared.bottomPadding))"
            bottomPaddingField.translatesAutoresizingMaskIntoConstraints = false
            bottomPaddingField.widthAnchor.constraint(equalToConstant: 60).isActive = true

            bottomPaddingStepper = NSStepper()
            bottomPaddingStepper.minValue = 0
            bottomPaddingStepper.maxValue = 100
            bottomPaddingStepper.integerValue = Int(Settings.shared.bottomPadding)
            bottomPaddingStepper.tag = 1
            bottomPaddingStepper.target = self
            bottomPaddingStepper.action = #selector(paddingStepperChanged(_:))
            bottomPaddingStepper.translatesAutoresizingMaskIntoConstraints = false

            let bottomPadReset = NSButton(title: "Reset", target: self, action: #selector(resetBottomPadding))
            bottomPadReset.bezelStyle = .rounded
            bottomPadReset.font = .systemFont(ofSize: 11)
            bottomPadReset.translatesAutoresizingMaskIntoConstraints = false

            let bottomPaddingRow = NSStackView(views: [bottomPaddingLabel, bottomPaddingField, bottomPaddingStepper, bottomPadReset])
            bottomPaddingRow.spacing = 8
            bottomPaddingRow.alignment = .centerY
            bottomPaddingRow.translatesAutoresizingMaskIntoConstraints = false

            // Assemble text card
            let inset: CGFloat = 12
            headerRow.translatesAutoresizingMaskIntoConstraints = false
            hint.translatesAutoresizingMaskIntoConstraints = false
            topRow.translatesAutoresizingMaskIntoConstraints = false
            topPaddingRow.translatesAutoresizingMaskIntoConstraints = false
            bottomRow.translatesAutoresizingMaskIntoConstraints = false
            bottomPaddingRow.translatesAutoresizingMaskIntoConstraints = false

            card.addSubview(headerRow)
            card.addSubview(hint)
            card.addSubview(topRow)
            card.addSubview(topPaddingRow)
            card.addSubview(bottomRow)
            card.addSubview(bottomPaddingRow)
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

                topPaddingRow.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 8),
                topPaddingRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: inset),
                topPaddingRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -inset),

                bottomRow.topAnchor.constraint(equalTo: topPaddingRow.bottomAnchor, constant: 8),
                bottomRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: inset),
                bottomRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -inset),

                bottomPaddingRow.topAnchor.constraint(equalTo: bottomRow.bottomAnchor, constant: 8),
                bottomPaddingRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: inset),
                bottomPaddingRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -inset),

                card.bottomAnchor.constraint(equalTo: bottomPaddingRow.bottomAnchor, constant: 12),
            ])

            mainStack.addArrangedSubview(card)
            card.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
        }

        // ── Separator and bottom bar ──
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(sep)

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

        NotificationCenter.default.addObserver(
            self, selector: #selector(paddingFieldChanged),
            name: NSControl.textDidChangeNotification, object: topPaddingField)
        NotificationCenter.default.addObserver(
            self, selector: #selector(paddingFieldChanged),
            name: NSControl.textDidChangeNotification, object: bottomPaddingField)
    }

    @objc private func securityLevelChanged(_ sender: NSPopUpButton) {
        let val = sender.titleOfSelectedItem == "Low" ? "low" : "max"
        Settings.shared.securityLevel = val
    }

    @objc private func save() {
        commitPhrases()
        commitPadding()
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        topColorWellLight.deactivate()
        topColorWellDark.deactivate()
        bottomColorWellLight.deactivate()
        bottomColorWellDark.deactivate()
        commitPhrases()
        commitPadding()
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
        let s = Settings.shared
        switch sender.tag {
        case 0:  s.topPhraseColorLight    = sender.color
        case 1:  s.bottomPhraseColorLight = sender.color
        case 2:  s.topPhraseColorDark     = sender.color
        case 3:  s.bottomPhraseColorDark  = sender.color
        default: break
        }
        (NSApp.delegate as? AppDelegate)?.updateOverlayTextColors()
        previewWindow?.updateTextColors(
            topLight: s.topPhraseColorLight, topDark: s.topPhraseColorDark,
            bottomLight: s.bottomPhraseColorLight, bottomDark: s.bottomPhraseColorDark)
    }

    // MARK: - Padding

    @objc private func paddingStepperChanged(_ sender: NSStepper) {
        let val = sender.integerValue
        if sender.tag == 0 {
            Settings.shared.topPadding = Double(val)
            topPaddingField.stringValue = "\(val)"
        } else {
            Settings.shared.bottomPadding = Double(val)
            bottomPaddingField.stringValue = "\(val)"
        }
        commitPadding()
    }

    @objc private func paddingFieldChanged(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        let val = field.integerValue
        if field === topPaddingField {
            Settings.shared.topPadding = Double(val)
            topPaddingStepper.integerValue = val
        } else {
            Settings.shared.bottomPadding = Double(val)
            bottomPaddingStepper.integerValue = val
        }
        commitPadding()
    }

    @objc private func resetTopPadding() {
        Settings.shared.topPadding = 25
        topPaddingField.stringValue = "25"
        topPaddingStepper.integerValue = 25
        commitPadding()
    }

    @objc private func resetBottomPadding() {
        Settings.shared.bottomPadding = 20
        bottomPaddingField.stringValue = "20"
        bottomPaddingStepper.integerValue = 20
        commitPadding()
    }

    private func commitPadding() {
        Settings.shared.topPadding = Double(topPaddingField.integerValue)
        Settings.shared.bottomPadding = Double(bottomPaddingField.integerValue)
        (NSApp.delegate as? AppDelegate)?.updateOverlayPadding()
        previewWindow?.updatePadding(top: CGFloat(Settings.shared.topPadding), bottom: CGFloat(Settings.shared.bottomPadding))
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

    private func makeColorWellStack(well: NSColorWell, label: String) -> NSStackView {
        let lbl = NSTextField(labelWithString: label)
        lbl.font = .systemFont(ofSize: 9, weight: .medium)
        lbl.textColor = .secondaryLabelColor
        lbl.alignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [lbl, well])
        stack.orientation = .vertical
        stack.spacing = 2
        stack.alignment = .centerX
        return stack
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
        let s = Settings.shared
        overlayView.updateTextColors(topLight: s.topPhraseColorLight, topDark: s.topPhraseColorDark,
                                     bottomLight: s.bottomPhraseColorLight, bottomDark: s.bottomPhraseColorDark)
    }

    func updatePhrases(top: String, bottom: String) {
        overlayView.updatePhrases(top: top, bottom: bottom)
    }

    func updateTextColors(topLight: NSColor, topDark: NSColor, bottomLight: NSColor, bottomDark: NSColor) {
        overlayView.updateTextColors(topLight: topLight, topDark: topDark,
                                     bottomLight: bottomLight, bottomDark: bottomDark)
    }

    func updatePadding(top: CGFloat, bottom: CGFloat) {
        overlayView.updatePadding(top: top, bottom: bottom)
    }
}
