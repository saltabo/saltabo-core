import AppKit

final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "macwindow.badge.plus", accessibilityDescription: "SwitchTab")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open App Switcher", action: #selector(openSwitcher), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "Request Permissions", action: #selector(openPermissionsFlow), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }

        item.menu = menu
        statusItem = item
    }

    @objc private func openSwitcher() {
        AppSwitcherManager.shared.showSwitcherForCurrentSpace()
    }

    @objc private func openPermissionsFlow() {
        AccessibilityService.shared.presentPermissionAlertIfNeeded()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
