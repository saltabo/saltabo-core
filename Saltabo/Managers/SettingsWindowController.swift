import AppKit

private final class BadgeStatusView: NSView {
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.masksToBounds = true

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.alignment = .center
        label.lineBreakMode = .byClipping

        addSubview(label)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 92),
            heightAnchor.constraint(equalToConstant: 24),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(text: String, textColor: NSColor, backgroundColor: NSColor) {
        label.stringValue = text
        label.textColor = textColor
        layer?.backgroundColor = backgroundColor.cgColor
    }
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private let shortcutPopup = NSPopUpButton()
    private let accessibilityStatusField = BadgeStatusView(frame: .zero)
    private let screenRecordingStatusField = BadgeStatusView(frame: .zero)
    private let permissionsStack = NSStackView()
    private var shouldRestoreAfterSystemSettings = false
    private var wasSuppressedForSwitcher = false

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.collectionBehavior = [.moveToActiveSpace]
        window.animationBehavior = .utilityWindow
        window.delegate = self
        window.contentView = buildContentView()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshPermissionState),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncShortcutSelection),
            name: .switcherShortcutDidChange,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWorkspaceAppDeactivation(_:)),
            name: NSWorkspace.didDeactivateApplicationNotification,
            object: nil
        )

        syncShortcutSelection()
        refreshPermissionState()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func showSettings() {
        syncShortcutSelection()
        refreshPermissionState()
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window?.orderFrontRegardless()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideSettingsIfVisible() {
        guard let window, window.isVisible else { return }
        shouldRestoreAfterSystemSettings = false
        window.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    func suppressForSwitcherIfVisible() {
        guard let window, window.isVisible else { return }
        shouldRestoreAfterSystemSettings = false
        wasSuppressedForSwitcher = true
        window.orderOut(nil)
    }

    func finishSwitcherInteraction(didActivateOtherApp: Bool) {
        defer {
            wasSuppressedForSwitcher = false
        }

        guard wasSuppressedForSwitcher else {
            if didActivateOtherApp {
                NSApp.setActivationPolicy(.accessory)
            }
            return
        }

        guard let window else { return }

        if didActivateOtherApp {
            window.orderOut(nil)
            NSApp.setActivationPolicy(.accessory)
            return
        }

        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func prepareToRestoreAfterSystemSettings() {
        shouldRestoreAfterSystemSettings = window?.isVisible == true
    }

    private func buildContentView() -> NSView {
        let rootView = NSView()
        rootView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 18
        container.translatesAutoresizingMaskIntoConstraints = false

        container.addArrangedSubview(makeSectionTitle("Keyboard Shortcut"))
        container.addArrangedSubview(makeShortcutRow())
        container.addArrangedSubview(
            makeSectionNote("Changes apply immediately to the global switcher shortcut."))
        container.addArrangedSubview(makeDivider())
        container.addArrangedSubview(makeSectionTitle("Permissions"))
        permissionsStack.orientation = .vertical
        permissionsStack.alignment = .leading
        permissionsStack.spacing = 10
        permissionsStack.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(permissionsStack)
        container.addArrangedSubview(
            makeSectionNote(
                "Saltabo needs Accessibility and Screen Recording."
            ))

        rootView.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 24),
            container.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -24),
            container.bottomAnchor.constraint(
                lessThanOrEqualTo: rootView.bottomAnchor, constant: -24),
        ])

        return rootView
    }

    private func makeSectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .labelColor
        return label
    }

    private func makeSectionNote(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        return label
    }

    private func makeDivider() -> NSBox {
        let divider = NSBox()
        divider.boxType = .separator
        return divider
    }

    private func makeShortcutRow() -> NSView {
        shortcutPopup.translatesAutoresizingMaskIntoConstraints = false
        shortcutPopup.target = self
        shortcutPopup.action = #selector(shortcutChanged(_:))
        shortcutPopup.removeAllItems()
        shortcutPopup.addItems(withTitles: SwitcherShortcut.allCases.map(\.displayName))

        let title = NSTextField(labelWithString: "Switcher shortcut")
        title.font = .systemFont(ofSize: 13, weight: .medium)

        let row = NSStackView(views: [title, shortcutPopup])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        shortcutPopup.widthAnchor.constraint(equalToConstant: 100).isActive = true
        return row
    }

    private func makePermissionRow(
        title: String,
        statusField: BadgeStatusView,
        openAction: Selector
    ) -> NSView {
        let titleField = NSTextField(labelWithString: title)
        titleField.font = .systemFont(ofSize: 13, weight: .medium)

        let openButton = NSButton(title: "Open System Settings", target: self, action: openAction)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [titleField, spacer, statusField, openButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10

        return row
    }

    @objc private func shortcutChanged(_ sender: NSPopUpButton) {
        let selectedIndex = sender.indexOfSelectedItem
        guard SwitcherShortcut.allCases.indices.contains(selectedIndex) else { return }
        AppSettings.shared.switcherShortcut = SwitcherShortcut.allCases[selectedIndex]
        AppSwitcherManager.shared.start()
    }

    @objc private func syncShortcutSelection() {
        let shortcut = AppSettings.shared.switcherShortcut
        if let index = SwitcherShortcut.allCases.firstIndex(of: shortcut) {
            shortcutPopup.selectItem(at: index)
        }
    }

    @objc private func openAccessibilitySettings() {
        prepareToRestoreAfterSystemSettings()
        AccessibilityService.shared.openAccessibilitySettings()
    }

    @objc private func openScreenRecordingSettings() {
        prepareToRestoreAfterSystemSettings()
        _ = AccessibilityService.shared.requestScreenRecordingPermission()
        AccessibilityService.shared.openScreenRecordingSettings()
    }

    @objc private func refreshPermissionState() {
        let snapshot = AccessibilityService.shared.currentPermissionSnapshot()
        rebuildPermissionRows()
        applyStatus(snapshot.accessibilityGranted, to: accessibilityStatusField)
        applyStatus(snapshot.screenRecordingGranted, to: screenRecordingStatusField)
    }

    private func applyStatus(_ granted: Bool, to field: BadgeStatusView) {
        field.configure(
            text: granted ? "Granted" : "Missing",
            textColor: granted
                ? NSColor.systemGreen.blended(withFraction: 0.25, of: .labelColor) ?? .systemGreen
                : .systemRed,
            backgroundColor: granted
                ? NSColor.systemGreen.withAlphaComponent(0.12)
                : NSColor.systemRed.withAlphaComponent(0.12)
        )
    }

    @objc private func handleWorkspaceAppDeactivation(_ notification: Notification) {
        guard shouldRestoreAfterSystemSettings,
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication,
            app.bundleIdentifier == "com.apple.systempreferences"
                || app.bundleIdentifier == "com.apple.SystemSettings"
        else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, self.window?.isVisible == true else { return }
            NSApp.setActivationPolicy(.regular)
            self.showWindow(nil)
            self.window?.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        shouldRestoreAfterSystemSettings = false
        wasSuppressedForSwitcher = false
        NSApp.setActivationPolicy(.accessory)
    }

    private func rebuildPermissionRows() {
        let desiredRows: [NSView] = [
            makePermissionRow(
                title: "Accessibility",
                statusField: accessibilityStatusField,
                openAction: #selector(openAccessibilitySettings)
            ),
            makePermissionRow(
                title: "Screen Recording",
                statusField: screenRecordingStatusField,
                openAction: #selector(openScreenRecordingSettings)
            ),
        ]

        permissionsStack.arrangedSubviews.forEach {
            permissionsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        desiredRows.forEach { permissionsStack.addArrangedSubview($0) }
    }
}
