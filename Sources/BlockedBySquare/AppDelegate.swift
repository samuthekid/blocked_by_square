import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindows: [OverlayWindow] = []
    var eventTap: CFMachPort?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !checkAccessibility() { return }
        setupWindows()
        setupEventTap()
        setupMouseTracking()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func checkAccessibility() -> Bool {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        )

        if !trusted {
            AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            )

            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = """
                BlockedBySquare needs Accessibility access to block keyboard and mouse input.

                1. Click "Open System Settings" below
                2. Find "BlockedBySquare" (or Terminal) and toggle it ON
                3. Reopen BlockedBySquare
                """
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Quit")
            alert.alertStyle = .warning

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            NSApp.terminate(nil)
            return false
        }
        return true
    }

    private func setupWindows() {
        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)
            overlayWindows.append(window)
            window.makeKeyAndOrderFront(nil)
        }
    }

    // Polls the global cursor position at 60 Hz and routes it to the correct window.
    // This is more reliable than NSEvent routing for cross-monitor tracking.
    private func setupMouseTracking() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let pos = NSEvent.mouseLocation
            for window in self.overlayWindows {
                if window.frame.contains(pos) {
                    let local = CGPoint(x: pos.x - window.frame.minX, y: pos.y - window.frame.minY)
                    window.showSquare(at: local)
                } else {
                    window.hideSquare()
                }
            }
        }
    }

    func setupEventTap() {
        let eventsToCapture: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
            .scrollWheel
        ]

        let eventMask = eventsToCapture.reduce(CGEventMask(0)) { mask, type in
            mask | (1 << type.rawValue)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: globalEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("⚠️  Event tap creation failed — re-check Accessibility permission.")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func lockAndQuit() {
        // Disable event tap first so the Ctrl+Cmd+Q fallback in lockScreen() isn't
        // swallowed by our own tap (which returns nil for every event).
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        lockScreen()
        for w in overlayWindows { w.close() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            NSApp.terminate(nil)
        }
    }

    private func lockScreen() {
        // Primary: SACLockScreenImmediate from the private Login framework.
        // Correct framework: /System/Library/PrivateFrameworks/login.framework/login
        // Correct symbol: SACLockScreenImmediate (no trailing "ly")
        if let handle = dlopen(
            "/System/Library/PrivateFrameworks/login.framework/login",
            RTLD_LAZY | RTLD_LOCAL
        ), let sym = dlsym(handle, "SACLockScreenImmediate") {
            typealias LockFn = @convention(c) () -> Void
            unsafeBitCast(sym, to: LockFn.self)()
            dlclose(handle)
            return
        }

        // Fallback: inject Ctrl+Cmd+Q (lock screen shortcut since macOS High Sierra).
        // Event tap is already disabled above, so this reaches loginwindow unimpeded.
        let src = CGEventSource(stateID: .privateState)
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: src, virtualKey: 12, keyDown: down) else { continue }
            e.flags = [.maskCommand, .maskControl]
            e.post(tap: .cghidEventTap)
        }
    }
}

private func globalEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return nil }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = delegate.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return nil
    }

    if type == .keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == 53 {
            DispatchQueue.main.async { delegate.lockAndQuit() }
            return nil
        }
    }

    return nil
}
