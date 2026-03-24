import AppKit

@main
final class SwitchTabApp: NSObject, NSApplicationDelegate {
    private var appSwitcherManager: AppSwitcherManager { .shared }
    private var dockPreviewManager: DockPreviewManager { .shared }
    private var isSmokeTestMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-smoke-test")
    }

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

        if isSmokeTestMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.appSwitcherManager.showSwitcherForCurrentSpace()
            }
        }
    }
}
