import AppKit

// Non-editable display field that captures a key+modifier combo via a local event monitor.
// Click to start recording; press a modifier+key to set; ESC cancels.
class ShortcutField: NSTextField {
    var onShortcutChanged: ((Int, NSEvent.ModifierFlags) -> Void)?

    private var localMonitor: Any?
    private var isRecording = false
    private var savedValue = ""

    override init(frame: NSRect) {
        super.init(frame: frame)
        isEditable   = false
        isSelectable = false
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { stopRecording() }

    override func mouseDown(with event: NSEvent) {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        isRecording = true
        savedValue  = stringValue
        stringValue = "Press shortcut…"
        textColor   = .secondaryLabelColor

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }
            return self.handle(event)
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == 53 { // ESC — cancel recording
            stringValue = savedValue
            stopRecording()
            return nil
        }

        let modifiers = event.modifierFlags.intersection([.command, .shift, .control, .option])
        guard !modifiers.isEmpty else { return nil } // bare key — ignore

        let keyCode = Int(event.keyCode)
        stringValue = formatShortcut(keyCode: keyCode, modifiers: modifiers)
        textColor   = .labelColor
        onShortcutChanged?(keyCode, modifiers)
        stopRecording()
        return nil
    }

    private func stopRecording() {
        isRecording = false
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        textColor = .labelColor
    }
}

func formatShortcut(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> String {
    var s = ""
    if modifiers.contains(.control) { s += "⌃" }
    if modifiers.contains(.option)  { s += "⌥" }
    if modifiers.contains(.shift)   { s += "⇧" }
    if modifiers.contains(.command) { s += "⌘" }
    s += keyCodeToString(keyCode)
    return s
}

private func keyCodeToString(_ code: Int) -> String {
    let map: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 50: "`",
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 109: "F10", 111: "F12", 118: "F4", 120: "F2", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
    return map[code] ?? "(\(code))"
}
