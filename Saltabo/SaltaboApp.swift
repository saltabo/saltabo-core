import AppKit

/// LSUIElement apps often lack an Edit menu; handle standard editing shortcuts on the field so paste works.
private final class LicenseDialogTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
            let characters = event.charactersIgnoringModifiers?.lowercased()
        else {
            return super.performKeyEquivalent(with: event)
        }

        switch characters {
        case "a":
            currentEditor()?.selectAll(nil)
            return true
        case "c":
            currentEditor()?.copy(nil)
            return true
        case "v":
            currentEditor()?.paste(nil)
            return true
        case "x":
            currentEditor()?.cut(nil)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}

private enum TrialGatePurchaseLinks {
    static var licensePurchasePage: URL {
        let key = "SaltaboPurchaseURL"
        if let s = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            let url = URL(string: s), !s.isEmpty
        {
            return url
        }
        return URL(string: "https://saltabo.xyz/pricing")!
    }
}

@main
final class SaltaboApp: NSObject, NSApplicationDelegate {
    private var appSwitcherManager: AppSwitcherManager { .shared }
    private var dockPreviewManager: DockPreviewManager { .shared }
    private var hasStartedServices = false
    private var hasContinuedLaunchFlow = false
    private var licenseStatusObserver: NSObjectProtocol?
    private var trialAccessMonitorTimer: Timer?
    private var isPresentingTrialExpiredGate = false
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
        installLicenseAccessObserver()

        if AppAccessManager.shared.isBlocked {
            presentTrialExpiredGate()
        } else {
            continueLaunchFlowIfNeeded()
        }

        beginTrialExpiryMonitoringIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        trialAccessMonitorTimer?.invalidate()
        trialAccessMonitorTimer = nil
        if let observer = licenseStatusObserver {
            NotificationCenter.default.removeObserver(observer)
            licenseStatusObserver = nil
        }
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
        guard !isPresentingTrialExpiredGate else { return }
        isPresentingTrialExpiredGate = true

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        runTrialExpiredGateStep()
    }

    private func endTrialExpiredGateSession() {
        isPresentingTrialExpiredGate = false
    }

    private func runTrialExpiredGateStep() {
        guard AppAccessManager.shared.isBlocked else {
            endTrialExpiredGateSession()
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Your 14-day free trial has ended."
        alert.informativeText =
            "Activate with a license key, purchase a license, or quit Saltabo."
        alert.addButton(withTitle: "Enter License Key")
        alert.addButton(withTitle: "Buy a License")
        alert.addButton(withTitle: "Quit")

        switch alert.runModal() {
        case .alertThirdButtonReturn:
            endTrialExpiredGateSession()
            NSApp.terminate(nil)
        case .alertSecondButtonReturn:
            openLicensePurchaseURL()
            runTrialExpiredGateStep()
        case .alertFirstButtonReturn:
            presentEnterLicenseFlow { [weak self] in
                guard let self else { return }
                if AppAccessManager.shared.isBlocked {
                    self.runTrialExpiredGateStep()
                } else {
                    self.endTrialExpiredGateSession()
                }
            }
        default:
            endTrialExpiredGateSession()
        }
    }

    /// Activate | Buy a License | Cancel. Completion runs when user leaves this flow (or license activated).
    private func presentEnterLicenseFlow(done: @escaping () -> Void) {
        guard AppAccessManager.shared.isBlocked else {
            done()
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        let fieldWidth: CGFloat = 310
        let fieldHeight: CGFloat = 28
        let container = NSView(
            frame: NSRect(x: 0, y: 0, width: fieldWidth, height: fieldHeight))
        let field = LicenseDialogTextField(string: AppSettings.shared.licenseKey)
        field.frame = NSRect(x: 0, y: 0, width: fieldWidth, height: fieldHeight)
        field.placeholderString =
            "STB-XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.isEditable = true
        field.isSelectable = true
        container.addSubview(field)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Enter your license key"
        alert.informativeText =
            "Paste or type your key, then choose Activate. You can also open the purchase page to buy a license."
        alert.accessoryView = container
        alert.addButton(withTitle: "Activate")
        alert.addButton(withTitle: "Buy a License")
        alert.addButton(withTitle: "Cancel")

        DispatchQueue.main.async {
            alert.window.makeFirstResponder(field)
        }

        let response = alert.runModal()
        switch response {
        case .alertThirdButtonReturn:
            done()
        case .alertSecondButtonReturn:
            openLicensePurchaseURL()
            presentEnterLicenseFlow(done: done)
        case .alertFirstButtonReturn:
            let trimmed = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                presentEmptyLicenseKeyAlert()
                presentEnterLicenseFlow(done: done)
                return
            }
            // Completion runs on main (LicenseManager.activate).
            LicenseManager.shared.activate(with: trimmed) { [weak self] result in
                guard let self else {
                    done()
                    return
                }
                NSApp.activate(ignoringOtherApps: true)

                switch result {
                case .success:
                    self.respondToPossibleLicenseActivation()
                case .failure(let error):
                    let errAlert = NSAlert()
                    errAlert.alertStyle = .warning
                    errAlert.messageText = "Activation failed."
                    errAlert.informativeText = error.errorDescription ?? "Unknown error."
                    errAlert.addButton(withTitle: "OK")
                    errAlert.runModal()
                }

                if AppAccessManager.shared.isBlocked {
                    self.presentEnterLicenseFlow(done: done)
                } else {
                    done()
                }
            }
        default:
            done()
        }
    }

    private func presentEmptyLicenseKeyAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "License key is empty."
        alert.informativeText =
            "Please enter a key in the format STB-XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func openLicensePurchaseURL() {
        NSWorkspace.shared.open(TrialGatePurchaseLinks.licensePurchasePage)
    }

    private func installLicenseAccessObserver() {
        guard licenseStatusObserver == nil else { return }
        licenseStatusObserver = NotificationCenter.default.addObserver(
            forName: .licenseStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.respondToPossibleLicenseActivation()
        }
    }

    private func respondToPossibleLicenseActivation() {
        guard LicenseManager.shared.status == .active else { return }
        guard !AppAccessManager.shared.isBlocked else { return }

        if hasContinuedLaunchFlow {
            startServicesIfNeeded()
        } else {
            continueLaunchFlowIfNeeded()
        }
    }

    private func startServicesIfNeeded() {
        guard !hasStartedServices else { return }
        guard !AppAccessManager.shared.isBlocked else { return }

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

    private func beginTrialExpiryMonitoringIfNeeded() {
        guard !isSmokeTestMode else { return }
        trialAccessMonitorTimer?.invalidate()
        trialAccessMonitorTimer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.enforceTrialExpiryIfNeeded()
        }
        trialAccessMonitorTimer?.tolerance = 5
        if let timer = trialAccessMonitorTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func enforceTrialExpiryIfNeeded() {
        guard !isSmokeTestMode else { return }
        guard AppAccessManager.shared.isBlocked else { return }

        if hasStartedServices {
            suspendAllUserFacingServicesForTrialExpiry()
        }

        guard shouldPromptTrialExpiredGateNow() else { return }
        presentTrialExpiredGate()
    }

    private func shouldPromptTrialExpiredGateNow() -> Bool {
        guard !isPresentingTrialExpiredGate else { return false }

        let settingsWindowVisible =
            SettingsWindowController.shared.window.map { !$0.isMiniaturized && $0.isVisible } ?? false

        guard !settingsWindowVisible else {
            return false
        }

        return true
    }

    private func suspendAllUserFacingServicesForTrialExpiry() {
        appSwitcherManager.stop()
        dockPreviewManager.stop()
        UpdateChecker.shared.stopAutomaticChecks()
        MenuBarManager.shared.tearDownPresentation()
        hasStartedServices = false
    }
}
