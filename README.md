# BlockedBySquare

<p align="center"><img src="blockedbysquare_logo.png" alt="BlockedBySquare Logo" width="400" /></p>

A tiny macOS menu-bar app that blocks all keyboard and mouse input system-wide and wraps your cursor in a glowing glass square. Look, but don't touch.

**→ [samuapps.dev/blocked-by-square](https://samuapps.dev/blocked-by-square/)**

Download the latest build from [Releases](../../releases).

## Build from source

```bash
git clone https://github.com/samuthekid/blocked_by_square
cd blocked_by_square
./bundle.sh
open BlockedBySquare.app
```

Requires Xcode command line tools (`xcode-select --install`) and macOS 13+.

`bundle.sh` flags:

- `--run` — build, sign, and launch the app
- `--settings` — launch with the Settings window open (handy while iterating on the UI)
- `--reset` — clear saved settings to defaults; only fires when launching, so pair it: `./bundle.sh --run --reset`
- `--release` — Developer ID sign + Hardened Runtime + notarize + staple, for distribution. Requires `DEVID_IDENTITY`, `APPLE_ID`, and `TEAM_ID` env vars (and prompts for an app-specific password)

## How it works

- **Input blocking** — a `CGEvent` tap at session scope swallows every keystroke and click before it reaches any app
- **Overlay** — borderless `NSWindow` per display, just below screen-saver level
- **Cursor tracking** — 60 Hz `Timer` poll (more reliable across monitors than `NSEvent` routing)
- **The square** — native glass effect on macOS 26+, `NSVisualEffectView` on older versions
- **Screen lock** — `SACLockScreenImmediate` from the private `login.framework`, falling back to Ctrl+Cmd+Q
- **Global shortcut** — `NSEvent.addGlobalMonitorForEvents` while idle

Needs **Accessibility** permission to install the system-wide event tap (System Settings → Privacy & Security → Accessibility).

## License

MIT
