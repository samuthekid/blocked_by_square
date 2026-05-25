import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var lockMenuItem: NSMenuItem?
    private var settingsController: SettingsWindowController?

    // Lock-mode state
    private var overlayWindows: [OverlayWindow] = []
    var eventTap: CFMachPort?
    private var mouseTimer: Timer?
    private(set) var isLocked = false

    // Global shortcut monitor (active only when NOT in lock mode)
    private var hotkeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !checkAccessibility() { return }
        setupStatusBar()
        setupGlobalShortcut()
        if Bundle.main.infoDictionary?["BlockedBySquareOpenSettingsOnLaunch"] as? Bool == true {
            DispatchQueue.main.async { self.openSettings() }
        }
    }

    // MARK: - Menu Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem?.button {
            btn.image = NSImage(systemSymbolName: "lock.square.fill", accessibilityDescription: "BlockedBySquare")
        }

        let menu = NSMenu()
        let lockItem = NSMenuItem(title: "Lock Now", action: #selector(lockNow), keyEquivalent: "")
        lockItem.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)
        applyShortcutDisplay(to: lockItem)
        lockMenuItem = lockItem
        menu.addItem(lockItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit BlockedBySquare", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func lockNow() {
        activateLockMode()
    }

    @objc private func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController()
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Global Shortcut

    func setupGlobalShortcut() {
        if let old = hotkeyMonitor { NSEvent.removeMonitor(old); hotkeyMonitor = nil }

        let targetCode = Settings.shared.shortcutKeyCode
        let targetMods = NSEvent.ModifierFlags(rawValue: Settings.shared.shortcutModifiers)

        hotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, !self.isLocked else { return }
            let mods = event.modifierFlags.intersection([.command, .shift, .control, .option])
            if Int(event.keyCode) == targetCode && mods == targetMods {
                DispatchQueue.main.async { self.activateLockMode() }
            }
        }
    }

    func updateGlobalShortcut() {
        setupGlobalShortcut()
        applyShortcutDisplay(to: lockMenuItem)
    }

    private func applyShortcutDisplay(to item: NSMenuItem?) {
        item?.keyEquivalent = keyCodeToMenuEquivalent(Settings.shared.shortcutKeyCode)
        item?.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: Settings.shared.shortcutModifiers)
    }

    // MARK: - Lock Mode

    private func activateLockMode() {
        guard !isLocked else { return }
        isLocked = true

        // Tear down shortcut monitor — the event tap blocks everything during lock
        if let m = hotkeyMonitor { NSEvent.removeMonitor(m); hotkeyMonitor = nil }

        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)
            overlayWindows.append(window)
            window.makeKeyAndOrderFront(nil)
        }
        updateOverlayPhrases()
        updateOverlayTextColors()

        startMouseTracking()
        startEventTap()
        NSApp.activate(ignoringOtherApps: true)
    }

    func deactivateLockMode() {
        guard isLocked else { return }
        isLocked = false

        mouseTimer?.invalidate()
        mouseTimer = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }

        lockScreen()

        for w in overlayWindows { w.close() }
        overlayWindows.removeAll()

        // Re-arm the global shortcut after a short delay so the ESC key event
        // dispatched during deactivation doesn't accidentally re-trigger anything.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.setupGlobalShortcut()
        }
    }

    func updateOverlayPhrases() {
        let top    = Settings.shared.topPhrase
        let bottom = Settings.shared.bottomPhrase
        for w in overlayWindows { w.updatePhrases(top: top, bottom: bottom) }
    }

    func updateOverlayTextColors() {
        let s = Settings.shared
        for w in overlayWindows {
            w.updateTextColors(topLight: s.topPhraseColorLight, topDark: s.topPhraseColorDark,
                               bottomLight: s.bottomPhraseColorLight, bottomDark: s.bottomPhraseColorDark)
        }
    }

    // MARK: - Mouse Tracking

    private func startMouseTracking() {
        mouseTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
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

    // MARK: - Event Tap

    private func startEventTap() {
        let eventsToCapture: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
            .scrollWheel
        ]

        let mask = eventsToCapture.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: globalEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("⚠️  Event tap creation failed — re-check Accessibility permission.")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // MARK: - Screen Lock

    private func lockScreen() {
        if let handle = dlopen(
            "/System/Library/PrivateFrameworks/login.framework/login",
            RTLD_LAZY | RTLD_LOCAL
        ), let sym = dlsym(handle, "SACLockScreenImmediate") {
            typealias LockFn = @convention(c) () -> Void
            unsafeBitCast(sym, to: LockFn.self)()
            dlclose(handle)
            return
        }

        // Fallback: Ctrl+Cmd+Q. Tap is already disabled so this reaches loginwindow.
        let src = CGEventSource(stateID: .privateState)
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: src, virtualKey: 12, keyDown: down) else { continue }
            e.flags = [.maskCommand, .maskControl]
            e.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Accessibility Check

    private func checkAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        if AXIsProcessTrustedWithOptions([key: false] as CFDictionary) { return true }

        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)

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

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        NSApp.terminate(nil)
        return false
    }
}

// MARK: - CGEvent Tap Callback (C function)

private func globalEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return nil }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = delegate.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
        return nil
    }

    if type == .keyDown, event.getIntegerValueField(.keyboardEventKeycode) == 53 {
        DispatchQueue.main.async { delegate.deactivateLockMode() }
    }

    return nil // swallow every event while locked
}
