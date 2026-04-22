import AppKit

final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?

    func setup() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMenubarIconStyleChange),
            name: .menubarIconStyleDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMenubarIconVisibilityChange),
            name: .menubarIconVisibilityDidChange,
            object: nil
        )
        applyMenubarVisibility()
    }

    @objc private func handleMenubarIconStyleChange() {
        applyMenubarIcon()
    }

    @objc private func handleMenubarIconVisibilityChange() {
        applyMenubarVisibility()
    }

    private func applyMenubarVisibility() {
        if AppSettings.shared.menubarIconVisible {
            ensureStatusItem()
            applyMenubarIcon()
        } else {
            removeStatusItem()
        }
    }

    private func ensureStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "Saltabo"

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Check for Updates...",
                action: #selector(checkForUpdates),
                keyEquivalent: ""
            ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(title: "About Saltabo...", action: #selector(openAbout), keyEquivalent: "")
        )
        menu.addItem(
            NSMenuItem(title: "Quit Saltabo", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }

        item.menu = menu
        statusItem = item
    }

    private func removeStatusItem() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func applyMenubarIcon() {
        guard let button = statusItem?.button else { return }
        button.image = menubarImage(for: AppSettings.shared.menubarIconStyle)
    }

    private func menubarImage(for style: MenubarIconStyle) -> NSImage? {
        let source: NSImage?
        switch style {
        case .default:
            source =
                NSImage(named: "ApplicationIcon256")
                ?? (NSApp.applicationIconImage.copy() as? NSImage)
                ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        case .minimal:
            source = NSImage(named: "MenubarIconMinimal")
        case .classic:
            source = NSImage(named: "MenubarIconClassic")
        }
        guard let source else { return nil }
        let icon = source.copy() as? NSImage ?? source
        icon.size = NSSize(width: 18, height: 18)
        icon.isTemplate = false
        return icon
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

    @objc private func checkForUpdates() {
        UpdateChecker.shared.checkForUpdates()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
