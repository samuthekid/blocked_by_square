# BlockedBySquare — Codebase Guide

macOS menu bar utility that blocks all input system-wide and displays a glowing glass square around the cursor. Triggered on demand via a configurable shortcut or the menu bar. Press ESC to either lock the screen or just exit lock mode (configurable).

---

## Build

```bash
# Compile only
swift build -c release

# Full app bundle + code signing (use this for distribution/testing)
./bundle.sh

# Additional bundle.sh flags:
# --run       Build and immediately open the app
# --settings  Build, open, and immediately show Settings window
# --reset     Launch with --reset to wipe all saved UserDefaults
```

`bundle.sh` creates the `.app` structure and signs it with a designated requirement keyed to the bundle ID (`com.blockedbysquare.app`), **not** the binary hash. This is intentional — it preserves the TCC Accessibility permission across rebuilds. Never replace this with `codesign --force --sign -` (ad-hoc), which would invalidate the permission on every rebuild.

---

## Architecture

| File | Role |
| ---- | ---- |
| `Sources/BlockedBySquare/main.swift` | Entry point. Sets activation policy to `.accessory`. Handles `--reset` CLI flag by calling `Settings.reset()` before launching. |
| `Sources/BlockedBySquare/AppDelegate.swift` | Core logic: menu bar item, accessibility check, global shortcut monitor, event tap, mouse tracking, screen lock. Lock mode is a toggleable state, not the entire app lifecycle. |
| `Sources/BlockedBySquare/Settings.swift` | Singleton persisting all user preferences to `UserDefaults`. Includes a static `reset()` method that wipes the bundle's defaults domain. |
| `Sources/BlockedBySquare/SettingsWindowController.swift` | Settings window UI (540×610). Card-based layout with live preview. Contains `PhraseField` (emoji-palette-aware `NSTextField`) and `LaunchToggle` (SwiftUI `SMAppService` toggle). |
| `Sources/BlockedBySquare/ShortcutRecorder.swift` | `ShortcutField` — `NSTextField` subclass that captures a key+modifier combo via a local event monitor. Also contains `formatShortcut`, `keyCodeToString`, and `keyCodeToMenuEquivalent` helpers. |
| `Sources/BlockedBySquare/OverlayWindow.swift` | One borderless fullscreen `NSWindow` per display. Created on lock activation, destroyed on deactivation. Ignores mouse events — the CGEvent tap handles blocking. |
| `Sources/BlockedBySquare/OverlayView.swift` | Renders the glass square. On macOS 26+ uses SwiftUI `GlassSquareView` with `.glassEffect`; on older macOS uses `NSVisualEffectView`. Two `CATextLayer`s for top/bottom text in a separate `textView` so opacity changes don't affect glass appearance. |

---

## App Lifecycle

The app starts idle in the menu bar. Lock mode is activated by:

- The configurable global keyboard shortcut (default: ⌘⇧L), monitored via `NSEvent.addGlobalMonitorForEvents`
- "Lock Now" in the menu bar menu

On ESC during lock mode: behavior depends on the **security level** setting:

- **Max** (default): screen is locked via `SACLockScreenImmediate` (or the Ctrl+Cmd+Q fallback), then overlays close and the event tap is disabled.
- **Low**: overlays close and event tap is disabled, no screen lock.

In both cases the global shortcut monitor is re-armed after a 300 ms delay to avoid accidentally re-triggering from the ESC event dispatch.

---

## Key Technical Decisions

**Event tap scope — `cgSessionEventTap`**
The tap is installed at session scope, not the default HID scope. This is required to block input globally before it reaches any application. The tap callback returns `nil` for every event, swallowing it. ESC (key code 53) is the only event acted on before being discarded. The tap also re-enables itself if disabled by timeout or user input.

**Global shortcut monitor — `NSEvent.addGlobalMonitorForEvents`**
Used only when NOT in lock mode to watch for the activation shortcut. It observes events without blocking them (unlike the CGEvent tap). The monitor is torn down before the event tap is enabled, and re-armed after lock mode exits (with a 300 ms delay).

**Mouse tracking — 60 Hz `Timer` poll**
`NSEvent` mouse-moved events are unreliable for cross-monitor tracking when the app has no key window. A repeating `Timer` at ~16.67 ms polls `NSEvent.mouseLocation` and routes to the matching overlay window.

**Window level — `.screenSaverWindow - 1`**
The overlay windows sit above almost everything but below the actual screen saver. `canBecomeKey` and `canBecomeMain` are both `false` — the windows never steal focus. `collectionBehavior` includes `.canJoinAllSpaces` and `.fullScreenAuxiliary`. Windows are created fresh on each lock activation so screen configuration changes are picked up.

**Security level**
Controlled by `Settings.shared.securityLevel` ("max" or "low"). Checked in `deactivateLockMode()`. "Max" calls `lockScreen()`; "Low" skips it. Both close overlays and re-arm the shortcut.

**Screen lock**
Primary: loads `SACLockScreenImmediate` from the private `login.framework` at runtime via `dlopen`/`dlsym`. Fallback: injects a Ctrl+Cmd+Q `CGEvent` (the standard lock shortcut since High Sierra). The event tap is disabled before locking so the injected event isn't swallowed.

**Glass square rendering (`OverlayView.swift`)**
Branched on OS version:

- **macOS 26+**: `NSHostingView` wrapping a SwiftUI `GlassSquareView` with `.glassEffect(.regular, in: RoundedRectangle)`. The system handles the glass material; a white glow shadow is applied to the hosting layer.
- **macOS 13–25**: `NSVisualEffectView` with `.hudWindow` material, `.behindWindow` blending, 20 pt continuous corner radius, 0.4-opacity white border, and a white glow shadow.

Text layers live in a sibling `textView` NSView so that changing the glass opacity never affects text rendering. Colors are updated in `viewDidChangeEffectiveAppearance()` to respond to system appearance changes at runtime.

**CATextLayer coordinate note**
`CATextLayer` renders text starting from the **top of its frame** downward. In a non-flipped `NSView`, CALayer coordinates have y=0 at the bottom. `updatePadding(top:bottom:)` places the top text so its frame's maxY = `squareSize - topPadding`, and the bottom text's frame starts at y = `bottomPadding`.

**Shortcut recorder (`ShortcutRecorder.swift`)**
`ShortcutField` is an `NSTextField` with `isEditable = false`. `mouseDown` installs a local event monitor (`NSEvent.addLocalMonitorForEvents`) that intercepts `keyDown` before dispatch — necessary because the field editor would otherwise steal focus and swallow events. The monitor is removed immediately after a valid combo is captured or ESC cancels.

**Live settings preview**
`SettingsWindowController` owns a `PreviewWindow` (a 220×220 borderless `NSWindow`) that is added as a child window below the settings panel. It shows a live `OverlayView` that updates in real time as the user types phrases, adjusts colors, padding, font sizes, and opacity — without requiring Save.

**Launch at login**
`LaunchToggle` (a SwiftUI `View` embedded via `NSHostingView`) registers/unregisters the app as a login item using `SMAppService.mainApp`.

**Emoji palette support**
`PhraseField` overrides `performKeyEquivalent` to open the system character palette (⌘⌃Space) when that combo is pressed, since `NSTextView`/field-editor shortcuts don't always propagate correctly.

---

## Permissions

Requires Accessibility (`AXIsProcessTrustedWithOptions`). Checked in `applicationDidFinishLaunching` — shows an alert with a direct link to System Settings, then terminates if denied. The permission is tied to the app bundle's code signature, which is why the designated-requirement signing strategy matters.

`NSEvent.addGlobalMonitorForEvents` for keyboard events also relies on Accessibility being granted.

---

## Platform Constraints

- **Minimum OS:** macOS 13 Ventura (`Package.swift` target, `Info.plist` `LSMinimumSystemVersion`)
- Glass effect: `.glassEffect` API is macOS 26+ only; `NSVisualEffectView` is used as fallback
- `SACLockScreenImmediate` is a private symbol — it could break in future OS versions; the fallback handles this gracefully
- `LSUIElement = true` in `Info.plist` keeps the app out of the Dock and App Switcher; the `NSStatusItem` provides the only UI entry point
- `BlockedBySquareOpenSettingsOnLaunch` in `Info.plist` (injected by `bundle.sh --settings`) causes the settings window to open immediately after launch — used for development only
