# BlockedBySquare

Lock your Mac in style.

BlockedBySquare blocks all keyboard and mouse input the moment it launches, wrapping your cursor in a glowing glass square so everyone knows the screen is intentionally locked. Press **ESC** to lock the screen and quit.

---

## What it does

- Intercepts **all keyboard and mouse input** system-wide — nothing gets through
- Renders a **glass-effect glowing square** that follows the cursor across all displays
- Press **ESC** to trigger a screen lock and exit cleanly

---

## Requirements

- macOS 13 Ventura or later
- Accessibility permission (required for system-wide input blocking)

---

## Installation

**Download (recommended)**

Grab the latest `BlockedBySquare.app` from [Releases](../../releases).

**Build from source**

```bash
git clone https://github.com/your-username/blocked_by_square
cd blocked_by_square
./bundle.sh
open BlockedBySquare.app
```

Requires Xcode command line tools (`xcode-select --install`).

---

## Usage

1. Launch `BlockedBySquare.app`
2. On first run, macOS will prompt for **Accessibility permission** — grant it in **System Settings → Privacy & Security → Accessibility**
3. Relaunch the app — the screen is now blocked
4. Press **ESC** to lock your Mac and quit

---

## How it works

A few things worth knowing under the hood:

- **Input blocking** uses a `CGEvent` tap at session scope — every keystroke and mouse event is swallowed before it reaches any app
- **Overlay windows** are borderless `NSWindow`s created per display, sitting just below screen-saver level so they cover everything
- **Cursor tracking** runs at 60 Hz via a `Timer` poll rather than `NSEvent` routing — more reliable across monitors
- **The square** is pure `CALayer` composition: a semi-transparent fill, a diagonal specular gradient, and a white glow shadow — no images
- **Screen lock** calls `SACLockScreenImmediate` from the private `login.framework`, falling back to injecting Ctrl+Cmd+Q if needed

---

## Permissions

BlockedBySquare requires **Accessibility** access to install a system-wide event tap. Without it, macOS won't allow the app to intercept input from other processes.

If the app quits immediately, open **System Settings → Privacy & Security → Accessibility** and make sure BlockedBySquare is enabled.

---

## License

MIT
