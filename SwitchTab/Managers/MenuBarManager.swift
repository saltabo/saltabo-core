import AppKit

final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let icon = NSApp.applicationIconImage.copy() as? NSImage {
            icon.size = NSSize(width: 24, height: 24)
            icon.isTemplate = false
            item.button?.image = icon
        }
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "SwitchTab"

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(title: "About SwitchTab...", action: #selector(openAbout), keyEquivalent: "")
        )
        menu.addItem(
            NSMenuItem(title: "Quit SwitchTab", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }

        item.menu = menu
        statusItem = item
    }

    @objc private func openSwitcher() {
        AppSwitcherManager.shared.showSwitcherForCurrentSpace()
    }

    @objc private func openSettings() {
        DispatchQueue.main.async {
            SettingsWindowController.shared.showSettings()
        }
    }

    @objc private func openAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let shortVersion =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0.0"
        let buildVersion =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationVersion: shortVersion,
            .version: "Build \(buildVersion)",
        ])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
