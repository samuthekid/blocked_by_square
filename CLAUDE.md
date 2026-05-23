# BlockedBySquare — Codebase Guide

macOS utility that blocks all input system-wide and displays a glowing glass square around the cursor. Press ESC to lock the screen and quit.

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
|------|------|
| `Sources/BlockedBySquare/main.swift` | Entry point. Sets activation policy to `.accessory` (no Dock icon, no menu bar). |
| `Sources/BlockedBySquare/AppDelegate.swift` | Core logic: accessibility check, event tap, mouse tracking, screen lock. |
| `Sources/BlockedBySquare/OverlayWindow.swift` | One borderless fullscreen `NSWindow` per display. Ignores mouse events — the CGEvent tap handles blocking. |
| `Sources/BlockedBySquare/OverlayView.swift` | Renders the glass square via three `CALayer` sublayers. |

---

## Key Technical Decisions

**Event tap scope — `cgSessionEventTap`**
The tap is installed at session scope, not the default HID scope. This is required to block input globally before it reaches any application. The tap callback returns `nil` for every event, swallowing it. ESC (key code 53) is the only event acted on before being discarded.

**Mouse tracking — 60 Hz `Timer` poll**
`NSEvent` mouse-moved events are unreliable for cross-monitor tracking when the app has no key window. A repeating `Timer` at ~16.67 ms polls `NSEvent.mouseLocation` and `NSScreen.screens` directly.

**Window level — `.screenSaver - 1`**
The overlay windows sit above almost everything but below the actual screen saver. `canBecomeKey` and `canBecomeMain` are both `false` — the windows never steal focus.

**Screen lock**
Primary: loads `SACLockScreenImmediate` from the private `login.framework` at runtime via `dlopen`/`dlsym`. Fallback: injects a Ctrl+Cmd+Q `CGEvent` (the standard lock shortcut since High Sierra). The event tap is disabled before locking so the injected event isn't swallowed.

**Glass square rendering (`OverlayView.swift`)**
Three `CALayer` sublayers on a clipped rounded-rect view:
1. Semi-transparent white fill (22% opacity)
2. Diagonal specular gradient (white, top-right to bottom-left, 45% → 8% → 0%)
3. White glow shadow on the container layer (blur radius 28, no offset)

---

## Permissions

Requires Accessibility (`AXIsProcessTrustedWithOptions`). Checked in `applicationDidFinishLaunching` — app terminates if denied. The permission is tied to the app bundle's code signature, which is why the designated-requirement signing strategy matters.

---

## Platform Constraints

- **Minimum OS:** macOS 13 Ventura (`Package.swift` target, `Info.plist` `LSMinimumSystemVersion`)
- `SACLockScreenImmediate` is a private symbol — it could break in future OS versions; the fallback handles this gracefully
- `LSUIElement = true` in `Info.plist` keeps the app out of the Dock and App Switcher
