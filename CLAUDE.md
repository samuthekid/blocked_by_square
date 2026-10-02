# BlockedBySquare — Codebase Guide

macOS menu-bar app (no Dock icon). On a shortcut, it installs a system-wide
CGEvent tap that swallows all keyboard/mouse input and draws a glowing glass
square around the cursor. ESC exits — and locks the screen unless security
level is "low". The default level is "max" (`Settings.defaultSecurityLevel`).
Swift Package Manager, no Xcode project, ~1.8k lines.

## Build & run

```bash
swift build -c release      # compile only
./bundle.sh                 # build → .app → ad-hoc sign (use this, not raw swift build)
./bundle.sh --run           # ...and launch
./bundle.sh --run --reset   # ...and wipe saved UserDefaults first (--reset only acts on launch)
./bundle.sh --settings      # ...and open Settings on launch (dev-only Info.plist key)
./bundle.sh --release       # Developer ID + Hardened Runtime + notarize + staple + BlockedBySquare.zip
```

`--release` also writes the stapled `BlockedBySquare.zip`. This is the file to
upload to GitHub Releases.

The build is arm64 only, on purpose. This is an owner decision: Apple Silicon
only, no universal binary (macOS 26 is the last Intel macOS).

Version numbers are hard-coded in the `Info.plist` heredoc in `bundle.sh`.
Bump both `CFBundleVersion` and `CFBundleShortVersionString` (now `1.0`) for
each release. The same `Info.plist` sets `CFBundleIconFile` = `AppIcon`.

There is no test target — verify by running the app.

**Signing matters more than usual here.** Default `bundle.sh` signs with a
designated requirement keyed to the *bundle ID* (`com.blockedbysquare.app`),
not the binary hash. This keeps the TCC Accessibility grant alive across
rebuilds. **Do not** switch to plain ad-hoc (`codesign --sign -` without the
`--requirements`) — every rebuild would change the cdhash and force the user
to re-grant Accessibility.

`--release` needs `DEVID_IDENTITY`, `APPLE_ID`, `TEAM_ID` (prompts for an
app-specific password). `notarize.sh` is a thin wrapper with those values
hard-coded for the owner's account. It is gitignored. Never commit it.

## Release process

v1.0 shipped on 2026-10-02.

1. Make changes, run `./bundle.sh --run`, and the OWNER hand-tests the dev
   build. Never notarize before the owner approves.
2. Commit and push.
3. The owner runs `./notarize.sh`. It holds the Apple ID and is never
   committed. It prompts for the app-specific password, which is never stored.
4. Verify:
   - `xcrun stapler validate BlockedBySquare.app`
   - `spctl -a -vvv -t install BlockedBySquare.app` shows "Notarized Developer ID"
   - `lipo -archs BlockedBySquare.app/Contents/MacOS/BlockedBySquare` shows `arm64`
5. The owner creates the GitHub release in the web UI (no `gh` CLI). Use tag
   `vX.Y` (created on publish), attach `BlockedBySquare.zip`, and mark it as
   latest. Then CHECK that the asset is attached:
   `https://github.com/samuthekid/blocked_by_square/releases/latest/download/BlockedBySquare.zip`
   must return 200. v1.0 was first published with no asset.

Gotchas:

- If `notarytool` fails with HTTP 403 "A required agreement is missing or has
  expired", the Account Holder must accept the updated agreement at
  developer.apple.com/account.
- If `bundle.sh --release` stops after the upload, check `spctl`. Apple may
  have accepted the app anyway. Then run `xcrun stapler staple BlockedBySquare.app`
  and `ditto -c -k --keepParent BlockedBySquare.app BlockedBySquare.zip` by hand.

## Files

| File | Role |
| ---- | ---- |
| `main.swift` | Entry point. `.accessory` activation policy; handles `--reset`. |
| `AppDelegate.swift` | Everything runtime: menu bar, accessibility check, global shortcut, event tap, mouse polling, screen lock. Lock mode is a toggled state, not the app lifecycle. |
| `Settings.swift` | `UserDefaults`-backed singleton. All defaults live as `static let`s at the top; `reset()` wipes the domain. |
| `SettingsWindowController.swift` | Settings UI (~950 lines) with a live preview window. Contains `PhraseField` (emoji-palette-aware) and `LaunchToggle` (`SMAppService` login item). |
| `ShortcutRecorder.swift` | `ShortcutField` captures a key+modifier combo via a local event monitor; key-code formatting helpers. |
| `OverlayWindow.swift` | One borderless fullscreen window per display, created on lock, destroyed on exit. |
| `OverlayView.swift` | The glass square: SwiftUI `.glassEffect` on macOS 26+, `NSVisualEffectView` fallback below. |
| `Resources/AppIcon.icns` | App icon (made from the website `logo.png` with `iconutil`). `bundle.sh` copies it into the bundle. |

## Flow

Idle in the menu bar. **Activate** (global shortcut `⌘⇧L` by default, or "Lock
Now"): unregister the shortcut hotkey, spawn an overlay per screen, start the
60 Hz mouse timer, install the event tap. **Exit** (ESC, key code 53): disable
the tap, lock the screen if `securityLevel == "max"`, close overlays, re-register
the shortcut hotkey after 300 ms.

## Gotchas (the non-obvious stuff)

- **Event tap is `.cgSessionEventTap`, not HID scope** — required to swallow
  input before any app sees it. The callback returns `nil` for everything
  except: ESC (triggers exit) and `keyUp` (passed through, see below). It also
  re-enables itself on `tapDisabledByTimeout`/`ByUserInput`.

- **`keyUp` is deliberately let through** (`globalEventCallback` in
  `AppDelegate.swift`, the `if type == .keyUp` branch near the end). It keeps
  the system's per-key state balanced. A key-*down* can reach the system before
  the tap exists, for example a key held when the lock starts. If we swallowed
  its key-*up*, the system would think that key is held forever and eat the
  next press. This was the "L key stuck" bug, from when the shortcut was not
  yet a Carbon hotkey. The Carbon hotkey now consumes the shortcut's key-down,
  but keep the rule. A key-up alone produces no input, so blocking is
  unaffected. Don't "simplify" it to swallow everything.

- **Mouse tracked by a 60 Hz `Timer`**, not `NSEvent` mouse-moved. Move events
  are unreliable across monitors when the app has no key window; the timer
  polls `NSEvent.mouseLocation` and routes to the containing overlay.

- **Screen lock uses a private symbol.** `SACLockScreenImmediate` from
  `login.framework`, loaded via `dlopen`/`dlsym`. If that ever fails it falls
  back to injecting Ctrl+Cmd+Q. The tap is disabled *before* locking so the
  injected event isn't swallowed.

- **Hotkey vs. event tap are mutually exclusive.** The shortcut is a Carbon
  hotkey (`RegisterEventHotKey`, so the combo is consumed and never reaches the
  frontmost app); it is registered *only* when idle, the tap runs *only* when
  locked. The 300 ms re-arm delay on exit stops the ESC dispatch from
  re-triggering. `ShortcutField` unregisters the hotkey while recording, or it
  would swallow the current combo.

- **`CATextLayer` y-coordinates are top-down inside a bottom-up CALayer.**
  `OverlayView.updatePadding` accounts for this — top text frame's maxY =
  `squareSize - topPadding`, bottom text starts at `y = bottomPadding`. Text
  lives in a sibling `textView` so opacity changes don't touch the glass.

- **Tap failure → `abortLock()`, not `deactivateLockMode()`.** If
  `CGEvent.tapCreate` fails (Accessibility revoked while running),
  `abortLock()` undoes the lock and shows an `NSAlert`. Do not use
  `deactivateLockMode()` there, because in Max mode it calls `lockScreen()`.

- **`LaunchToggle` uses a `reverting` flag.** On an `SMAppService` error it
  sets `isOn` back and shows an `NSAlert`. Setting `isOn` fires `onChange`
  again, and the flag skips that call.

- **`hotkeyHandlerInstalled` must stay.** Each `InstallEventHandler` call adds
  another handler. Without the flag, handlers stack up on every shortcut change.

- **Errors shown to the user use `NSAlert` only.** No UserNotifications. This
  is decided, so the app needs no extra permission prompt.

- **Settings has separate light/dark phrase colors** with a fallback to the
  old single-color keys (`topPhraseColor`/`bottomPhraseColor`) for migration.

## Permissions & platform

- **Accessibility is mandatory** (`AXIsProcessTrustedWithOptions`, checked at
  launch — alert + System Settings deep link, then quit if denied). The
  event tap needs it. The grant is tied to the code
  signature — hence the signing note above. The Carbon hotkey itself does not
  need Accessibility.
- **macOS 13+** (`Package.swift`, `Info.plist LSMinimumSystemVersion`).
- `LSUIElement = true` → no Dock, no app switcher; the status item is the only
  entry point. `Info.plist` is generated by `bundle.sh`, not committed.

## Website and public claims

The marketing page lives in the sibling repo `../website/public/blocked-by-square/`
(`index.html` and `privacy.html`). Cloudflare Workers serves it from `main` of
`samuthekid/website`. The page and the privacy policy promise:

- macOS 13+ on Apple Silicon
- notarized
- Max is the default ESC mode
- real Liquid Glass only on macOS 26+
- NO data collected and NO network access
- Accessibility is used only to watch for the shortcut and to block input while locked

If a code change breaks any of these claims (for example it adds networking or
changes a default), update the website pages too. The download buttons point at
`/releases/latest`.

## Deferred (v1.0.1 cleanup)

A ponytail audit found about 88 lines that could go. They were not removed, to
avoid retesting v1.0:

- `Settings.swift`: one color archive helper. The 4 color properties repeat
  archive/unarchive and migration.
- `SettingsWindowController.swift`: one reset helper for the 5 `reset*` methods.
- `ShortcutRecorder.swift`: a shared base map for `keyCodeToMenuEquivalent` and
  `keyCodeToString`.
- `SettingsWindowController.swift`: reuse one `NumberFormatter` for the
  identical `padFmt` and `btmFmt`.
