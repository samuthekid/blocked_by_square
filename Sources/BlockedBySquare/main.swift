import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // No dock icon, no menu bar
let delegate = AppDelegate()
app.delegate = delegate
app.run()
