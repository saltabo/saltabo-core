import AppKit

@main
final class SaltaboApp: NSObject, NSApplicationDelegate {
    private var appSwitcherManager: AppSwitcherManager { .shared }
    private var dockPreviewManager: DockPreviewManager { .shared }
    private var hasStartedServices = false
    private var isSmokeTestMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-smoke-test")
    }

    static func main() {
        let app = NSApplication.shared
        let delegate = SaltaboApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if MoveToApplicationsManager.shared.promptIfNeeded() {
            return
        }

        if PermissionsWindowController.shared.presentIfNeeded(onContinue: { [weak self] in
            self?.startServicesIfNeeded()
        }) {
            return
        }

        startServicesIfNeeded()
    }

    private func startServicesIfNeeded() {
        guard !hasStartedServices else { return }
        hasStartedServices = true

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
