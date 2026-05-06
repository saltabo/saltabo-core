import AppKit

@main
final class SaltaboApp: NSObject, NSApplicationDelegate {
    private var appSwitcherManager: AppSwitcherManager { .shared }
    private var dockPreviewManager: DockPreviewManager { .shared }
    private var hasStartedServices = false
    private var hasContinuedLaunchFlow = false
    private var licenseStatusObserver: NSObjectProtocol?
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
        AppAccessManager.shared.bootstrapTrialIfNeeded()
        guard !AppAccessManager.shared.isBlocked else {
            presentTrialExpiredGate()
            return
        }

        continueLaunchFlowIfNeeded()
    }

    private func continueLaunchFlowIfNeeded() {
        guard !hasContinuedLaunchFlow else { return }
        hasContinuedLaunchFlow = true

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

    private func presentTrialExpiredGate() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Your 14-day free trial has ended."
        alert.informativeText =
            "Activate a license key to continue using Saltabo."
        alert.addButton(withTitle: "Enter License")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            watchForLicenseActivation()
            SettingsWindowController.shared.showSettings()
            return
        }
        NSApp.terminate(nil)
    }

    private func watchForLicenseActivation() {
        guard licenseStatusObserver == nil else { return }
        licenseStatusObserver = NotificationCenter.default.addObserver(
            forName: .licenseStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if !AppAccessManager.shared.isBlocked {
                if let observer = self.licenseStatusObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self.licenseStatusObserver = nil
                }
                self.continueLaunchFlowIfNeeded()
            }
        }
    }

    private func startServicesIfNeeded() {
        guard !hasStartedServices else { return }
        hasStartedServices = true

        MenuBarManager.shared.setup()
        UpdateChecker.shared.startAutomaticChecksIfNeeded()
        appSwitcherManager.start()
        dockPreviewManager.start()

        if !AppSettings.shared.menubarIconVisible {
            DispatchQueue.main.async {
                SettingsWindowController.shared.showSettings()
            }
        }

        if isSmokeTestMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.appSwitcherManager.showSwitcherForCurrentSpace()
            }
        }
    }
}
