# BlockedBySquare — Codebase Guide

macOS menu-bar app (no Dock icon). On a shortcut, it installs a system-wide
CGEvent tap that swallows all keyboard/mouse input and draws a glowing glass
square around the cursor. ESC exits — and locks the screen unless security
level is "low". Swift Package Manager, no Xcode project, ~1.8k lines.

## Build & run

```bash
swift build -c release      # compile only
./bundle.sh                 # build → .app → ad-hoc sign (use this, not raw swift build)
./bundle.sh --run           # ...and launch
./bundle.sh --run --reset   # ...and wipe saved UserDefaults first (--reset only acts on launch)
./bundle.sh --settings      # ...and open Settings on launch (dev-only Info.plist key)
./bundle.sh --release       # Developer ID + Hardened Runtime + notarize + staple
```

There is no test target — verify by running the app.

**Signing matters more than usual here.** Default `bundle.sh` signs with a
designated requirement keyed to the *bundle ID* (`com.blockedbysquare.app`),
not the binary hash. This keeps the TCC Accessibility grant alive across
rebuilds. **Do not** switch to plain ad-hoc (`codesign --sign -` without the
`--requirements`) — every rebuild would change the cdhash and force the user
to re-grant Accessibility.

`--release` needs `DEVID_IDENTITY`, `APPLE_ID`, `TEAM_ID` (prompts for an
app-specific password). `notarize.sh` is a thin wrapper with those values
hard-coded for the owner's account.

## Files

| File | Role |
| ---- | ---- |
| `main.swift` | Entry point. `.accessory` activation policy; handles `--reset`. |
| `AppDelegate.swift` | Everything runtime: menu bar, accessibility check, global shortcut, event tap, mouse polling, screen lock. Lock mode is a toggled state, not the app lifecycle. |
| `Settings.swift` | `UserDefaults`-backed singleton. All defaults live as `static let`s at the top; `reset()` wipes the domain. |
| `SettingsWindowController.swift` | Settings UI (~940 lines) with a live preview window. Contains `PhraseField` (emoji-palette-aware) and `LaunchToggle` (`SMAppService` login item). |
| `ShortcutRecorder.swift` | `ShortcutField` captures a key+modifier combo via a local event monitor; key-code formatting helpers. |
| `OverlayWindow.swift` | One borderless fullscreen window per display, created on lock, destroyed on exit. |
| `OverlayView.swift` | The glass square: SwiftUI `.glassEffect` on macOS 26+, `NSVisualEffectView` fallback below. |

## Flow

Idle in the menu bar. **Activate** (global shortcut `⌘⇧L` by default, or "Lock
Now"): tear down the shortcut monitor, spawn an overlay per screen, start the
60 Hz mouse timer, install the event tap. **Exit** (ESC, key code 53): disable
the tap, lock the screen if `securityLevel == "max"`, close overlays, re-arm
the shortcut monitor after 300 ms.

## Gotchas (the non-obvious stuff)

- **Event tap is `.cgSessionEventTap`, not HID scope** — required to swallow
  input before any app sees it. The callback returns `nil` for everything
  except: ESC (triggers exit) and `keyUp` (passed through, see below). It also
  re-enables itself on `tapDisabledByTimeout`/`ByUserInput`.

- **`keyUp` is deliberately let through** (`AppDelegate.swift` ~L307). The
  activation shortcut's key-*down* leaks in before the tap exists; if we also
  swallowed its key-*up*, the system would think that key is held forever and
  eat the next press. This is the "L key stuck" fix — don't "simplify" it to
  swallow everything.

- **Mouse tracked by a 60 Hz `Timer`**, not `NSEvent` mouse-moved. Move events
  are unreliable across monitors when the app has no key window; the timer
  polls `NSEvent.mouseLocation` and routes to the containing overlay.

- **Screen lock uses a private symbol.** `SACLockScreenImmediate` from
  `login.framework`, loaded via `dlopen`/`dlsym`. If that ever fails it falls
  back to injecting Ctrl+Cmd+Q. The tap is disabled *before* locking so the
  injected event isn't swallowed.

- **Global monitor vs. event tap are mutually exclusive.** The shortcut
  monitor (`addGlobalMonitorForEvents`, observe-only) runs *only* when idle;
  the tap runs *only* when locked. The 300 ms re-arm delay on exit stops the
  ESC dispatch from re-triggering.

- **`CATextLayer` y-coordinates are top-down inside a bottom-up CALayer.**
  `OverlayView.updatePadding` accounts for this — top text frame's maxY =
  `squareSize - topPadding`, bottom text starts at `y = bottomPadding`. Text
  lives in a sibling `textView` so opacity changes don't touch the glass.

- **Settings has separate light/dark phrase colors** with a fallback to the
  old single-color keys (`topPhraseColor`/`bottomPhraseColor`) for migration.

## Permissions & platform

- **Accessibility is mandatory** (`AXIsProcessTrustedWithOptions`, checked at
  launch — alert + System Settings deep link, then quit if denied). Both the
  event tap and the global monitor need it. The grant is tied to the code
  signature — hence the signing note above.
- **macOS 13+** (`Package.swift`, `Info.plist LSMinimumSystemVersion`).
- `LSUIElement = true` → no Dock, no app switcher; the status item is the only
  entry point. `Info.plist` is generated by `bundle.sh`, not committed.
