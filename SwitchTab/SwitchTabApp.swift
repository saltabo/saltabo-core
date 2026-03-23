import AppKit

@main
final class SwitchTabApp: NSObject, NSApplicationDelegate {
    private var appSwitcherManager: AppSwitcherManager { .shared }
    private var dockPreviewManager: DockPreviewManager { .shared }

    static func main() {
        let app = NSApplication.shared
        let delegate = SwitchTabApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AccessibilityService.shared.presentPermissionAlertIfNeeded()
        MenuBarManager.shared.setup()
        appSwitcherManager.start()
        dockPreviewManager.start()
    }
}
