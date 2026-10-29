import AppKit

let application = NSApplication.shared
// No Dock icon: PR Pets lives on the desktop and, optionally, in the menu bar.
application.setActivationPolicy(.accessory)
let delegate = MainActor.assumeIsolated { AppDelegate() }
application.delegate = delegate
application.run()
