# BlockedBySquare — Codebase Guide

macOS menu bar utility that blocks all input system-wide and displays a glowing glass square around the cursor. Triggered on demand via a configurable shortcut or the menu bar. Press ESC to lock the screen and return to idle.

---

## Build

```bash
# Compile only
swift build -c release

# Full app bundle + code signing (use this for distribution)
./bundle.sh
```

`bundle.sh` creates the `.app` structure and signs it with a designated requirement keyed to the bundle ID (`com.blockedbysquare.app`), **not** the binary hash. This is intentional — it preserves the TCC Accessibility permission across rebuilds. Never replace this with `codesign --force --sign -` (ad-hoc), which would invalidate the permission on every rebuild.

---

## Architecture

| File | Role |
| ---- | ---- |
| `Sources/BlockedBySquare/main.swift` | Entry point. Sets activation policy to `.accessory` (no Dock icon, no menu bar icon from NSApp). |
| `Sources/BlockedBySquare/AppDelegate.swift` | Core logic: menu bar item, accessibility check, global shortcut monitor, event tap, mouse tracking, screen lock. Lock mode is a toggleable state, not the entire app lifecycle. |
| `Sources/BlockedBySquare/Settings.swift` | Singleton persisting shortcut keycode, modifier flags, and two text phrases to `UserDefaults`. |
| `Sources/BlockedBySquare/SettingsWindowController.swift` | Settings window UI: shortcut recorder field, top/bottom phrase text fields, Save button. |
| `Sources/BlockedBySquare/ShortcutRecorder.swift` | `NSTextField` subclass that captures a key+modifier combo via a local event monitor. Also contains `formatShortcut` and `keyCodeToString` helpers. |
| `Sources/BlockedBySquare/OverlayWindow.swift` | One borderless fullscreen `NSWindow` per display. Created on lock activation, destroyed on deactivation. Ignores mouse events — the CGEvent tap handles blocking. |
| `Sources/BlockedBySquare/OverlayView.swift` | Renders the glass square via `CALayer` sublayers plus two `CATextLayer`s for the top/bottom phrases. |

---

## App Lifecycle

The app starts idle in the menu bar. Lock mode is activated by:

- The configurable global keyboard shortcut (default: ⌘⇧L), monitored via `NSEvent.addGlobalMonitorForEvents`
- "Lock Now" in the menu bar menu

On ESC during lock mode: the screen is locked, overlays are closed, the event tap is disabled, and the global shortcut monitor is re-armed. The app stays running.

---

## Key Technical Decisions

**Event tap scope — `cgSessionEventTap`**
The tap is installed at session scope, not the default HID scope. This is required to block input globally before it reaches any application. The tap callback returns `nil` for every event, swallowing it. ESC (key code 53) is the only event acted on before being discarded.

**Global shortcut monitor — `NSEvent.addGlobalMonitorForEvents`**
Used only when NOT in lock mode to watch for the activation shortcut. It observes events without blocking them (unlike the CGEvent tap). The monitor is torn down before the event tap is enabled, and re-armed after lock mode exits.

**Mouse tracking — 60 Hz `Timer` poll**
`NSEvent` mouse-moved events are unreliable for cross-monitor tracking when the app has no key window. A repeating `Timer` at ~16.67 ms polls `NSEvent.mouseLocation` and `NSScreen.screens` directly.

**Window level — `.screenSaver - 1`**
The overlay windows sit above almost everything but below the actual screen saver. `canBecomeKey` and `canBecomeMain` are both `false` — the windows never steal focus. Windows are created fresh on each lock activation so screen configuration changes are picked up.

**Screen lock**
Primary: loads `SACLockScreenImmediate` from the private `login.framework` at runtime via `dlopen`/`dlsym`. Fallback: injects a Ctrl+Cmd+Q `CGEvent` (the standard lock shortcut since High Sierra). The event tap is disabled before locking so the injected event isn't swallowed.

**Glass square rendering (`OverlayView.swift`)**
`CALayer` sublayers on a clipped rounded-rect view:

1. Semi-transparent white fill (22% opacity)
2. Diagonal specular gradient (white, top-right to bottom-left, 45% → 8% → 0%)
3. White glow shadow on the container layer (blur radius 28, no offset)
4. `CATextLayer` for the top phrase — frame top sits 25px below the square's top edge
5. `CATextLayer` for the bottom phrase — frame sized to single-line height so text bottom sits ~25px above the square's bottom edge (matching the top phrase's padding)

**CATextLayer coordinate note**
`CATextLayer` renders text starting from the **top of its frame** downward. In a non-flipped `NSView`, CALayer coordinates have y=0 at the bottom. The top phrase frame's maxY = 175 (25px from the 200px square's top). The bottom phrase frame is sized to ~22px tall with maxY = 42, so single-line text ends ~26px from the bottom edge.

**Shortcut recorder (`ShortcutRecorder.swift`)**
`NSTextField` with `isEditable = false`. `mouseDown` installs a local event monitor (`NSEvent.addLocalMonitorForEvents`) that intercepts `keyDown` before dispatch — this is necessary because `NSTextField`'s field editor would otherwise steal focus and swallow events. The monitor is removed immediately after a valid combo is captured or ESC cancels.

---

## Permissions

Requires Accessibility (`AXIsProcessTrustedWithOptions`). Checked in `applicationDidFinishLaunching` — app terminates if denied. The permission is tied to the app bundle's code signature, which is why the designated-requirement signing strategy matters.

`NSEvent.addGlobalMonitorForEvents` for keyboard events also relies on Accessibility being granted.

---

## Platform Constraints

- **Minimum OS:** macOS 13 Ventura (`Package.swift` target, `Info.plist` `LSMinimumSystemVersion`)
- `SACLockScreenImmediate` is a private symbol — it could break in future OS versions; the fallback handles this gracefully
- `LSUIElement = true` in `Info.plist` keeps the app out of the Dock and App Switcher; the `NSStatusItem` provides the only UI entry point
