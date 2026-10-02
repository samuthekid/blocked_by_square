import AppKit
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem?
  private var lockMenuItem: NSMenuItem?
  private var settingsController: SettingsWindowController?

  // Lock-mode state
  private var overlayWindows: [OverlayWindow] = []
  var eventTap: CFMachPort?
  private var mouseTimer: Timer?
  private(set) var isLocked = false

  // Global shortcut hotkey (registered only when NOT in lock mode)
  private var hotkeyRef: EventHotKeyRef?
  private var hotkeyHandlerInstalled = false

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
      btn.image = NSImage(
        systemSymbolName: "lock.square.fill", accessibilityDescription: "BlockedBySquare")
    }

    let menu = NSMenu()
    let lockItem = NSMenuItem(title: "Lock Now", action: #selector(lockNow), keyEquivalent: "")
    lockItem.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)
    applyShortcutDisplay(to: lockItem)
    lockMenuItem = lockItem
    menu.addItem(lockItem)
    menu.addItem(.separator())
    menu.addItem(
      NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
    menu.addItem(.separator())
    menu.addItem(
      NSMenuItem(
        title: "Quit BlockedBySquare", action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"))
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
    removeGlobalShortcut()

    // Carbon hotkeys consume the combo, so the frontmost app never sees it.
    if !hotkeyHandlerInstalled {
      var spec = EventTypeSpec(
        eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
      let status = InstallEventHandler(
        GetApplicationEventTarget(),
        { _, _, refcon in
          guard let refcon else { return OSStatus(eventNotHandledErr) }
          let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
          DispatchQueue.main.async {
            if !delegate.isLocked { delegate.activateLockMode() }
          }
          return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
      hotkeyHandlerInstalled = status == noErr
    }

    let mods = NSEvent.ModifierFlags(rawValue: Settings.shared.shortcutModifiers)
    var carbonMods: UInt32 = 0
    if mods.contains(.command) { carbonMods |= UInt32(cmdKey) }
    if mods.contains(.shift) { carbonMods |= UInt32(shiftKey) }
    if mods.contains(.option) { carbonMods |= UInt32(optionKey) }
    if mods.contains(.control) { carbonMods |= UInt32(controlKey) }

    // Fails if another app owns the combo — leave it unregistered, no crash.
    let id = EventHotKeyID(signature: OSType(0x4242_5351), id: 1)  // 'BBSQ'
    RegisterEventHotKey(
      UInt32(Settings.shared.shortcutKeyCode), carbonMods, id, GetApplicationEventTarget(), 0,
      &hotkeyRef)
  }

  func removeGlobalShortcut() {
    if let ref = hotkeyRef {
      UnregisterEventHotKey(ref)
      hotkeyRef = nil
    }
  }

  func updateGlobalShortcut() {
    setupGlobalShortcut()
    applyShortcutDisplay(to: lockMenuItem)
  }

  private func applyShortcutDisplay(to item: NSMenuItem?) {
    item?.keyEquivalent = keyCodeToMenuEquivalent(Settings.shared.shortcutKeyCode)
    item?.keyEquivalentModifierMask = NSEvent.ModifierFlags(
      rawValue: Settings.shared.shortcutModifiers)
  }

  // MARK: - Lock Mode

  private func activateLockMode() {
    guard !isLocked else { return }
    isLocked = true

    // Tear down shortcut hotkey — the event tap blocks everything during lock
    removeGlobalShortcut()

    for screen in NSScreen.screens {
      let window = OverlayWindow(screen: screen)
      overlayWindows.append(window)
      window.makeKeyAndOrderFront(nil)
    }
    updateOverlayPhrases()
    updateOverlayTextColors()
    updateOverlayTextAlpha()
    updateOverlayFontSizes()
    updateOverlayPadding()

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

    if Settings.shared.securityLevel == "max" {
      lockScreen()
    }

    for w in overlayWindows { w.close() }
    overlayWindows.removeAll()

    // Re-arm the global shortcut after a short delay so the ESC key event
    // dispatched during deactivation doesn't accidentally re-trigger anything.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      self?.setupGlobalShortcut()
    }
  }

  func updateOverlayPhrases() {
    let top = Settings.shared.topPhrase
    let bottom = Settings.shared.bottomPhrase
    for w in overlayWindows { w.updatePhrases(top: top, bottom: bottom) }
  }

  func updateOverlayTextColors() {
    let s = Settings.shared
    for w in overlayWindows {
      w.updateTextColors(
        topLight: s.topPhraseColorLight, topDark: s.topPhraseColorDark,
        bottomLight: s.bottomPhraseColorLight, bottomDark: s.bottomPhraseColorDark)
    }
  }

  func updateOverlayTextAlpha() {
    for w in overlayWindows { w.updateTextAlpha() }
  }

  func updateOverlayFontSizes() {
    for w in overlayWindows { w.updateFontSizes() }
  }

  func updateOverlayPadding() {
    let s = Settings.shared
    for w in overlayWindows {
      w.updatePadding(top: CGFloat(s.topPadding), bottom: CGFloat(s.bottomPadding))
    }
  }

  // MARK: - Mouse Tracking

  private func startMouseTracking() {
    mouseTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) {
      [weak self] _ in
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
      .scrollWheel,
    ]

    let mask = eventsToCapture.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }

    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: globalEventCallback,
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      )
    else {
      abortLock()
      return
    }

    eventTap = tap
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
  }

  // MARK: - Screen Lock

  /// Tap creation fails when Accessibility access is gone. Undo the lock without
  /// lockScreen() (Max mode would lock the Mac) and tell the user why.
  private func abortLock() {
    isLocked = false
    mouseTimer?.invalidate()
    mouseTimer = nil
    for w in overlayWindows { w.close() }
    overlayWindows.removeAll()
    setupGlobalShortcut()

    let alert = NSAlert()
    alert.messageText = "Could Not Block Input"
    alert.informativeText = """
      BlockedBySquare has no Accessibility access, so the lock did not start.

      Turn BlockedBySquare ON in System Settings → Privacy & Security → Accessibility. \
      If it is already ON, turn it OFF and ON again, then reopen BlockedBySquare.
      """
    alert.addButton(withTitle: "Open System Settings")
    alert.addButton(withTitle: "Cancel")
    alert.alertStyle = .warning
    NSApp.activate(ignoringOtherApps: true)
    if alert.runModal() == .alertFirstButtonReturn { openAccessibilitySettings() }
  }

  private func openAccessibilitySettings() {
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    {
      NSWorkspace.shared.open(url)
    }
  }

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
      guard let e = CGEvent(keyboardEventSource: src, virtualKey: 12, keyDown: down) else {
        continue
      }
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
      2. Find "BlockedBySquare" and toggle it ON
      3. Reopen BlockedBySquare
      """
    alert.addButton(withTitle: "Open System Settings")
    alert.addButton(withTitle: "Quit")
    alert.alertStyle = .warning

    if alert.runModal() == .alertFirstButtonReturn { openAccessibilitySettings() }
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

  // Let key-up events through so the system's per-key state stays balanced.
  // The shortcut's key-down leaks in before the tap exists; swallowing its
  // key-up would leave that key logically "stuck down" (eats the next press).
  // Key-up alone produces no input, so blocking is unaffected.
  if type == .keyUp {
    return Unmanaged.passUnretained(event)
  }

  return nil  // swallow everything else while locked
}
