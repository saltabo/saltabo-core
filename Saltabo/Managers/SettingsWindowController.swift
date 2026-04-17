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

    private enum SettingsTab: CaseIterable {
        case appearance
        case controls
        case general
        case permissions

        var title: String {
            switch self {
            case .appearance: return "Appearance"
            case .controls: return "Controls"
            case .general: return "General"
            case .permissions: return "Permissions"
            }
        }

        var symbolName: String {
            switch self {
            case .appearance: return "paintpalette"
            case .controls: return "command"
            case .general: return "gearshape"
            case .permissions: return "accessibility"
            }
        }
    }

    private let shortcutPopup = NSPopUpButton()
    private let switcherSizeControl = NSSegmentedControl()
    private let switcherThemeControl = NSSegmentedControl()
    private let switcherReleaseActionPopup = NSPopUpButton()
    private let switcherPreviewSelectedWindowToggle = NSSwitch()
    private let accessibilityStatusField = BadgeStatusView(frame: .zero)
    private let screenRecordingStatusField = BadgeStatusView(frame: .zero)
    private let permissionsStack = NSStackView()
    private let tabStack = NSStackView()
    private let contentHostView = NSView()
    private var tabButtons: [SettingsTab: NSButton] = [:]
    private var tabViews: [SettingsTab: NSView] = [:]
    private var activeTab: SettingsTab = .general
    private var shouldRestoreAfterSystemSettings = false
    private var wasSuppressedForSwitcher = false
    private weak var switcherStyleThumbnailTile: NSButton?
    private weak var switcherStyleAppIconsTile: NSButton?
    private weak var switcherStyleListTile: NSButton?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 940, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
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
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.delegate = self
        window.contentView = buildContentView()
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
        window.standardWindowButton(.closeButton)?.isEnabled = true
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = true
        window.standardWindowButton(.zoomButton)?.isEnabled = true
        DispatchQueue.main.async { [weak self] in
            self?.layoutTrafficButtons()
        }

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshSwitcherStyleTileSelection),
            name: .switcherDisplayStyleDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncSwitcherSizeSelection),
            name: .switcherSizePresetDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncSwitcherThemeSelection),
            name: .switcherThemePresetDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncSwitcherReleaseActionSelection),
            name: .switcherReleaseActionDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncSwitcherPreviewSelectedWindowSelection),
            name: .switcherPreviewSelectedWindowDidChange,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWorkspaceAppDeactivation(_:)),
            name: NSWorkspace.didDeactivateApplicationNotification,
            object: nil
        )

        syncShortcutSelection()
        syncSwitcherSizeSelection()
        syncSwitcherThemeSelection()
        syncSwitcherReleaseActionSelection()
        syncSwitcherPreviewSelectedWindowSelection()
        refreshPermissionState()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func showSettings() {
        syncShortcutSelection()
        syncSwitcherSizeSelection()
        syncSwitcherThemeSelection()
        syncSwitcherReleaseActionSelection()
        syncSwitcherPreviewSelectedWindowSelection()
        refreshSwitcherStyleTileSelection()
        refreshPermissionState()
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window?.orderFrontRegardless()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in
            self?.layoutTrafficButtons()
        }
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

        let sidebarCardInset: CGFloat = 0
        let sidebarWidth: CGFloat = 260

        let sidebarShadowView = NSView()
        sidebarShadowView.translatesAutoresizingMaskIntoConstraints = false
        sidebarShadowView.wantsLayer = true
        sidebarShadowView.layer?.backgroundColor = NSColor.clear.cgColor
        sidebarShadowView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.24).cgColor
        sidebarShadowView.layer?.shadowOpacity = 0.2
        sidebarShadowView.layer?.shadowRadius = 18
        sidebarShadowView.layer?.shadowOffset = CGSize(width: 0, height: -5)

        let sidebar = NSView()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = NSColor(calibratedWhite: 0.96, alpha: 0.98).cgColor
        sidebar.layer?.cornerRadius = 22
        sidebar.layer?.borderWidth = 1
        sidebar.layer?.borderColor = NSColor.white.withAlphaComponent(0.78).cgColor

        let navigatorOutline = makeNavigatorOutline()
        let filterBar = makeSidebarFilterBar()

        tabStack.orientation = .vertical
        tabStack.alignment = .leading
        tabStack.spacing = 4
        tabStack.translatesAutoresizingMaskIntoConstraints = false

        SettingsTab.allCases.forEach { tab in
            let button = makeTabButton(tab: tab)
            tabButtons[tab] = button
            tabStack.addArrangedSubview(button)
        }
        tabButtons.values.forEach { button in
            button.widthAnchor.constraint(equalTo: tabStack.widthAnchor).isActive = true
        }

        contentHostView.translatesAutoresizingMaskIntoConstraints = false

        let appearanceTabView = buildAppearanceTabView()
        let controlsTabView = buildControlsTabView()
        let generalTabView = buildGeneralTabView()
        let exceptionsTabView = buildExceptionsTabView()
        tabViews[.appearance] = appearanceTabView
        tabViews[.controls] = controlsTabView
        tabViews[.general] = generalTabView
        tabViews[.permissions] = exceptionsTabView
        [appearanceTabView, controlsTabView, generalTabView, exceptionsTabView].forEach {
            contentHostView.addSubview($0)
            NSLayoutConstraint.activate([
                $0.topAnchor.constraint(equalTo: contentHostView.topAnchor),
                $0.leadingAnchor.constraint(equalTo: contentHostView.leadingAnchor),
                $0.trailingAnchor.constraint(equalTo: contentHostView.trailingAnchor),
                $0.bottomAnchor.constraint(equalTo: contentHostView.bottomAnchor),
            ])
        }
        activateTab(.appearance)

        sidebar.addSubview(navigatorOutline)
        navigatorOutline.addSubview(tabStack)
        sidebar.addSubview(filterBar)
        sidebarShadowView.addSubview(sidebar)
        rootView.addSubview(sidebarShadowView)
        rootView.addSubview(contentHostView)
        NSLayoutConstraint.activate([
            sidebarShadowView.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 6),
            sidebarShadowView.leadingAnchor.constraint(
                equalTo: rootView.leadingAnchor, constant: 6),
            sidebarShadowView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -6),
            sidebarShadowView.widthAnchor.constraint(
                equalToConstant: sidebarWidth + (sidebarCardInset * 2)),

            sidebar.topAnchor.constraint(equalTo: sidebarShadowView.topAnchor),
            sidebar.leadingAnchor.constraint(
                equalTo: sidebarShadowView.leadingAnchor, constant: sidebarCardInset),
            sidebar.trailingAnchor.constraint(
                equalTo: sidebarShadowView.trailingAnchor, constant: -sidebarCardInset),
            sidebar.bottomAnchor.constraint(
                equalTo: sidebarShadowView.bottomAnchor, constant: -sidebarCardInset),

            navigatorOutline.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 36),
            navigatorOutline.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 8),
            navigatorOutline.trailingAnchor.constraint(
                equalTo: sidebar.trailingAnchor, constant: -8),
            navigatorOutline.bottomAnchor.constraint(equalTo: filterBar.topAnchor, constant: -10),

            tabStack.topAnchor.constraint(equalTo: navigatorOutline.topAnchor, constant: 4),
            tabStack.leadingAnchor.constraint(equalTo: navigatorOutline.leadingAnchor, constant: 6),
            tabStack.trailingAnchor.constraint(
                equalTo: navigatorOutline.trailingAnchor, constant: -6),
            tabStack.bottomAnchor.constraint(
                lessThanOrEqualTo: navigatorOutline.bottomAnchor, constant: -8),

            filterBar.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            filterBar.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -12),
            filterBar.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -12),
            filterBar.heightAnchor.constraint(equalToConstant: 30),

            contentHostView.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 12),
            contentHostView.leadingAnchor.constraint(
                equalTo: sidebarShadowView.trailingAnchor, constant: 10),
            contentHostView.trailingAnchor.constraint(
                equalTo: rootView.trailingAnchor, constant: -12),
            contentHostView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -12),
        ])

        sidebarShadowView.layoutSubtreeIfNeeded()
        sidebarShadowView.layer?.shadowPath = CGPath(
            roundedRect: sidebar.frame,
            cornerWidth: 18,
            cornerHeight: 18,
            transform: nil
        )

        return rootView
    }

    private func makeNavigatorOutline() -> NSView {
        let outline = NSView()
        outline.translatesAutoresizingMaskIntoConstraints = false
        return outline
    }

    private func makeSidebarFilterBar() -> NSView {
        let bar = NSView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.wantsLayer = false

        let resetButton = NSButton(
            title: "Reset settings",
            target: self,
            action: #selector(resetSettingsAndRestart)
        )
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.isBordered = false
        resetButton.font = .systemFont(ofSize: 12, weight: .medium)
        resetButton.contentTintColor = .darkGray
        resetButton.wantsLayer = true
        resetButton.layer?.cornerRadius = 14
        resetButton.layer?.backgroundColor =
            NSColor.quaternaryLabelColor.withAlphaComponent(0.12).cgColor
        resetButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        resetButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        bar.addSubview(resetButton)

        NSLayoutConstraint.activate([
            resetButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 8),
            resetButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
            resetButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            resetButton.heightAnchor.constraint(equalToConstant: 28),
        ])

        return bar
    }

    private func makeInlineSymbolView(_ symbolName: String) -> NSImageView {
        let imageView = NSImageView(
            image: NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) ?? NSImage()
        )
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        imageView.contentTintColor = NSColor.secondaryLabelColor
        return imageView
    }

    private func buildAppearanceTabView() -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 16
        container.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        container.addArrangedSubview(makeSectionTitle("Appearance"))
        container.addArrangedSubview(
            makeSectionNote("Switch between different styles. You can customize them."))
        container.addArrangedSubview(makeStylePreviewRow())
        container.addArrangedSubview(makeSettingsCard())

        root.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),
            container.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            container.bottomAnchor.constraint(
                lessThanOrEqualTo: root.bottomAnchor, constant: -24),
        ])

        return root
    }

    private func buildControlsTabView() -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 12
        container.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        container.addArrangedSubview(makeSectionTitle("Controls"))
        container.addArrangedSubview(makeControlsTriggerCard())
        container.addArrangedSubview(makeControlsSettingsCard())

        root.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),
            container.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            container.bottomAnchor.constraint(
                lessThanOrEqualTo: root.bottomAnchor, constant: -24),
        ])
        return root
    }

    private func makeControlsTriggerCard() -> NSView {
        let card = NSView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor
        card.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        card.widthAnchor.constraint(equalToConstant: 610).isActive = true
        card.heightAnchor.constraint(equalToConstant: 54).isActive = true

        let triggerLabel = NSTextField(labelWithString: "Trigger")
        triggerLabel.translatesAutoresizingMaskIntoConstraints = false
        triggerLabel.font = .systemFont(ofSize: 13, weight: .regular)

        let holdLabel = NSTextField(labelWithString: "Hold")
        holdLabel.translatesAutoresizingMaskIntoConstraints = false
        holdLabel.font = .systemFont(ofSize: 13)

        let modifierPopup = NSPopUpButton()
        modifierPopup.translatesAutoresizingMaskIntoConstraints = false
        modifierPopup.addItems(withTitles: SwitcherShortcut.allCases.map(\.modifierSymbol))
        modifierPopup.controlSize = .regular
        modifierPopup.font = .systemFont(ofSize: 14, weight: .medium)
        modifierPopup.target = self
        modifierPopup.action = #selector(shortcutModifierChanged(_:))
        modifierPopup.widthAnchor.constraint(equalToConstant: 102).isActive = true

        let andPressLabel = NSTextField(labelWithString: "and press")
        andPressLabel.translatesAutoresizingMaskIntoConstraints = false
        andPressLabel.font = .systemFont(ofSize: 13)

        let keyCapsule = NSTextField(labelWithString: "⇥")
        keyCapsule.translatesAutoresizingMaskIntoConstraints = false
        keyCapsule.alignment = .center
        keyCapsule.font = .systemFont(ofSize: 14, weight: .medium)
        keyCapsule.wantsLayer = true
        keyCapsule.layer?.cornerRadius = 6
        keyCapsule.layer?.borderWidth = 1
        keyCapsule.layer?.borderColor = NSColor.separatorColor.cgColor
        keyCapsule.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        keyCapsule.widthAnchor.constraint(equalToConstant: 98).isActive = true
        keyCapsule.heightAnchor.constraint(equalToConstant: 24).isActive = true

        card.addSubview(triggerLabel)
        card.addSubview(holdLabel)
        card.addSubview(modifierPopup)
        card.addSubview(andPressLabel)
        card.addSubview(keyCapsule)

        NSLayoutConstraint.activate([
            triggerLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            triggerLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            holdLabel.leadingAnchor.constraint(equalTo: triggerLabel.trailingAnchor, constant: 24),
            holdLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            modifierPopup.leadingAnchor.constraint(equalTo: holdLabel.trailingAnchor, constant: 12),
            modifierPopup.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            andPressLabel.leadingAnchor.constraint(
                equalTo: modifierPopup.trailingAnchor, constant: 16),
            andPressLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            keyCapsule.leadingAnchor.constraint(
                equalTo: andPressLabel.trailingAnchor, constant: 12),
            keyCapsule.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])

        if let index = SwitcherShortcut.allCases.firstIndex(of: AppSettings.shared.switcherShortcut)
        {
            modifierPopup.selectItem(at: index)
        }

        return card
    }

    private func makeControlsSettingsCard() -> NSView {
        let card = NSView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor
        card.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        card.widthAnchor.constraint(equalToConstant: 610).isActive = true

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .leading

        stack.addArrangedSubview(
            makeControlsOptionRow(
                title: "Show windows from applications",
                options: ["All apps", "Active apps", "Non-active apps"], selectedIndex: 0,
                width: 126))
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(
            makeControlsOptionRow(
                title: "Show windows from screens",
                options: ["Current screen only", "All screens"], selectedIndex: 0,
                width: 180))
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(
            makeControlsOptionRow(
                title: "Show minimized windows", options: ["Show", "Hide"], selectedIndex: 0,
                width: 84))
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(
            makeControlsOptionRow(
                title: "Show fullscreen windows", options: ["Show", "Hide"], selectedIndex: 0,
                width: 84))
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(
            makeControlsOptionRow(
                title: "Order windows by",
                options: [
                    "Recently Focused First", "Recently Opened First", "Name A-z", "Name Z-a",
                ], selectedIndex: 0,
                width: 180))

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return card
    }

    private func makeControlsOptionRow(
        title: String,
        options: [String],
        selectedIndex: Int,
        width: CGFloat
    ) -> NSView {
        makeAppearanceControlRow(
            title: title,
            control: makeAppearancePopup(
                titles: options,
                selectedIndex: selectedIndex,
                width: width
            )
        )
    }

    private func buildGeneralTabView() -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 10
        container.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        container.addArrangedSubview(makeSectionTitle("General"))
        container.addArrangedSubview(makeGeneralPrimaryCard())
        container.addArrangedSubview(makeGeneralLanguageCard())
        container.addArrangedSubview(makeGeneralPoliciesCard())

        root.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),
            container.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            container.bottomAnchor.constraint(
                lessThanOrEqualTo: root.bottomAnchor, constant: -24),
        ])
        return root
    }

    private func makeGeneralPrimaryCard() -> NSView {
        let card = makeSettingsGroupCard(width: 610)

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .leading

        stack.addArrangedSubview(
            makeAppearanceControlRow(
                title: "Start at login",
                control: makeAppearanceSwitch(isOn: true)
            )
        )
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(
            makeGeneralMenubarRow()
        )
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(
            makeGeneralDescriptionRow(
                title: "Capture windows in the background",
                description:
                    "When disabled, avoids the macOS purple screen-recording indicator, and avoids flickers when playing DRM video. Thumbnails will be less up-to-date.",
                control: makeAppearanceSwitch(isOn: true)
            )
        )

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return card
    }

    private func makeGeneralLanguageCard() -> NSView {
        let card = makeSettingsGroupCard(width: 610)
        let row = makeAppearanceControlRow(
            title: "Language",
            control: makeAppearancePopup(
                titles: ["System Default", "English", "Vietnamese"],
                selectedIndex: 0,
                width: 140
            )
        )

        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return card
    }

    private func makeGeneralPoliciesCard() -> NSView {
        let card = makeSettingsGroupCard(width: 610)

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .leading

        stack.addArrangedSubview(
            makeAppearanceControlRow(
                title: "Updates policy",
                control: makeAppearancePopup(
                    titles: [
                        "Check for updates periodically",
                        "Check manually only",
                    ],
                    selectedIndex: 0,
                    width: 220
                )
            )
        )
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(
            makeAppearanceControlRow(
                title: "Crash reports policy",
                control: makeAppearancePopup(
                    titles: [
                        "Ask whether to send crash reports",
                        "Always send crash reports",
                        "Never send crash reports",
                    ],
                    selectedIndex: 0,
                    width: 260
                )
            )
        )

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return card
    }

    private func sizedMenubarPopupItemImage(_ source: NSImage) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        source.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: source.size),
            operation: .sourceOver,
            fraction: 1
        )
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func makeGeneralMenubarRow() -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Menubar icon")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        titleLabel.textColor = .labelColor

        let iconPopup = makeAppearancePopup(
            titles: ["", "", ""],
            selectedIndex: 0,
            width: 48
        )
        iconPopup.imagePosition = .imageOnly
        iconPopup.setAccessibilityLabel("Menubar icon style")
        if let iconItem = iconPopup.item(at: 0) {
            let appSource =
                NSImage(named: "ApplicationIcon256")
                ?? (NSApp.applicationIconImage.copy() as? NSImage)
                ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
            iconItem.image = sizedMenubarPopupItemImage(appSource)
        }
        if let item = iconPopup.item(at: 1), let asset = NSImage(named: "MenubarIconMinimal") {
            item.image = sizedMenubarPopupItemImage(asset)
        }
        if let item = iconPopup.item(at: 2), let asset = NSImage(named: "MenubarIconClassic") {
            item.image = sizedMenubarPopupItemImage(asset)
        }

        let toggle = makeAppearanceSwitch(isOn: true)

        row.addSubview(titleLabel)
        row.addSubview(iconPopup)
        row.addSubview(toggle)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
            toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            iconPopup.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -10),
            iconPopup.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconPopup.leadingAnchor.constraint(
                greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 16),
        ])

        return row
    }

    private func makeGeneralDescriptionRow(
        title: String,
        description: String,
        control: NSView
    ) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        titleLabel.textColor = .labelColor

        let descriptionLabel = NSTextField(wrappingLabelWithString: description)
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = .systemFont(ofSize: 12)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.maximumNumberOfLines = 0

        row.addSubview(titleLabel)
        row.addSubview(descriptionLabel)
        row.addSubview(control)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 76),

            titleLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),

            control.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            control.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            descriptionLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
            descriptionLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
            descriptionLabel.bottomAnchor.constraint(
                lessThanOrEqualTo: row.bottomAnchor, constant: -10),
        ])

        return row
    }

    private func makeSettingsGroupCard(width: CGFloat) -> NSView {
        let card = NSView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor
        card.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        card.widthAnchor.constraint(equalToConstant: width).isActive = true
        return card
    }

    private func buildExceptionsTabView() -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 18
        container.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

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

        root.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),
            container.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            container.bottomAnchor.constraint(
                lessThanOrEqualTo: root.bottomAnchor, constant: -24),
        ])

        return root
    }

    private func makeTabButton(tab: SettingsTab) -> NSButton {
        let button = NSButton(
            title: "  \(tab.title)", target: self, action: #selector(tabSelected(_:)))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.alignment = .left
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.identifier = NSUserInterfaceItemIdentifier(rawValue: tab.title)
        button.setButtonType(.momentaryPushIn)
        button.contentTintColor = .secondaryLabelColor
        button.image = makePaddedSymbolImage(tab.symbolName, leftInset: 8)
        button.imagePosition = .imageLeading
        button.imageHugsTitle = false
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.wantsLayer = true
        button.layer?.cornerRadius = 7
        button.heightAnchor.constraint(equalToConstant: 26).isActive = true
        button.attributedTitle = NSAttributedString(
            string: "  \(tab.title)",
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium)]
        )
        return button
    }

    private func makePaddedSymbolImage(_ symbolName: String, leftInset: CGFloat) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        else {
            return nil
        }

        let sourceSize = NSSize(width: 14, height: 14)
        symbol.size = sourceSize

        let outputSize = NSSize(width: sourceSize.width + leftInset, height: sourceSize.height)
        let output = NSImage(size: outputSize)
        output.lockFocus()
        symbol.draw(
            in: NSRect(x: leftInset, y: 0, width: sourceSize.width, height: sourceSize.height),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        output.unlockFocus()
        output.isTemplate = true
        return output
    }

    @objc private func tabSelected(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue
        else {
            return
        }
        guard let tab = SettingsTab.allCases.first(where: { $0.title == identifier }) else {
            return
        }
        activateTab(tab)
    }

    private func activateTab(_ tab: SettingsTab) {
        activeTab = tab
        tabViews.forEach { key, view in
            view.isHidden = key != tab
        }
        tabButtons.forEach { key, button in
            let isActive = key == tab
            button.layer?.backgroundColor =
                isActive
                ? NSColor.controlAccentColor.withAlphaComponent(0.16).cgColor
                : NSColor.clear.cgColor
            button.contentTintColor = isActive ? NSColor.controlAccentColor : .secondaryLabelColor
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: isActive ? .semibold : .medium),
                    .foregroundColor: isActive ? NSColor.labelColor : NSColor.secondaryLabelColor,
                ]
            )
        }
    }

    private func makeStylePreviewRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false

        let style = AppSettings.shared.switcherDisplayStyle
        let thumbnailsButton = makeSwitcherTile(
            tag: 0, imageName: "SwitcherStyleThumbnailsPreview", selected: style == .thumbnails)
        let appIconsButton = makeSwitcherTile(
            tag: 1, imageName: "SwitcherStyleAppIconsPreview", selected: style == .appIcons)
        let listButton = makeSwitcherTile(
            tag: 2, imageName: "SwitcherStyleListPreview", selected: style == .list)
        switcherStyleThumbnailTile = thumbnailsButton
        switcherStyleAppIconsTile = appIconsButton
        switcherStyleListTile = listButton

        row.addArrangedSubview(thumbnailsButton)
        row.addArrangedSubview(appIconsButton)
        row.addArrangedSubview(listButton)
        return row
    }

    private func makeSwitcherTile(tag: Int, imageName: String, selected: Bool) -> NSButton {
        let button = NSButton(
            title: "", target: self, action: #selector(switcherDisplayStyleTileClicked(_:)))
        button.tag = tag
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.bezelStyle = .shadowlessSquare
        button.setButtonType(.momentaryPushIn)
        button.image = NSImage(named: imageName)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleAxesIndependently
        button.widthAnchor.constraint(equalToConstant: 190).isActive = true
        button.heightAnchor.constraint(equalToConstant: 140).isActive = true
        applySwitcherStyleTileAppearance(to: button, selected: selected)
        return button
    }

    private func applySwitcherStyleTileAppearance(to button: NSButton, selected: Bool) {
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.layer?.borderWidth = selected ? 3 : 1
        button.layer?.borderColor =
            (selected ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
        button.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        let color = selected ? NSColor.labelColor : NSColor.secondaryLabelColor
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 18, weight: .medium),
                .foregroundColor: color,
            ]
        )
    }

    @objc private func switcherDisplayStyleTileClicked(_ sender: NSButton) {
        let newStyle: SwitcherDisplayStyle
        switch sender.tag {
        case 1:
            newStyle = .appIcons
        case 2:
            newStyle = .list
        default:
            newStyle = .thumbnails
        }
        AppSettings.shared.switcherDisplayStyle = newStyle
    }

    @objc private func refreshSwitcherStyleTileSelection() {
        let style = AppSettings.shared.switcherDisplayStyle
        if let button = switcherStyleThumbnailTile {
            applySwitcherStyleTileAppearance(to: button, selected: style == .thumbnails)
        }
        if let button = switcherStyleAppIconsTile {
            applySwitcherStyleTileAppearance(to: button, selected: style == .appIcons)
        }
        if let button = switcherStyleListTile {
            applySwitcherStyleTileAppearance(to: button, selected: style == .list)
        }
    }

    private func makeSettingsCard() -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor
        card.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        card.widthAnchor.constraint(equalToConstant: 610).isActive = true
        card.heightAnchor.constraint(equalToConstant: 163).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(
            makeAppearanceControlRow(
                title: "Size",
                control: makeSwitcherSizeControl()
            )
        )
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(
            makeAppearanceControlRow(
                title: "Theme",
                control: makeSwitcherThemeControl()
            )
        )
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(
            makeAppearanceControlRow(
                title: "After keys are released",
                control: makeSwitcherReleaseActionPopup()
            )
        )
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(
            makeAppearanceControlRow(
                title: "Dock shows window previews",
                control: makeSwitcherPreviewSelectedWindowToggle()
            )
        )

        // let customizeButton = NSButton(title: "Customize Titles style...", target: nil, action: nil)
        // customizeButton.translatesAutoresizingMaskIntoConstraints = false
        // customizeButton.bezelStyle = .rounded
        // customizeButton.controlSize = .small
        // customizeButton.font = .systemFont(ofSize: 12, weight: .medium)

        card.addSubview(stack)
        // card.addSubview(customizeButton)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 0),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 0),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: 0),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: 0),

            // customizeButton.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 14),
            // customizeButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            // customizeButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
        return card
    }

    private func makeAppearanceControlRow(title: String, control: NSView) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        titleLabel.textColor = .labelColor

        row.addSubview(titleLabel)
        row.addSubview(control)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            control.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
            control.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            control.leadingAnchor.constraint(
                greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 16),
        ])

        return row
    }

    private func makeSegmentedControl(labels: [String], selectedIndex: Int) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: labels, trackingMode: .selectOne, target: nil, action: nil)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.segmentStyle = .rounded
        control.selectedSegment = selectedIndex
        control.controlSize = .regular
        return control
    }

    private func makeSwitcherSizeControl() -> NSSegmentedControl {
        switcherSizeControl.translatesAutoresizingMaskIntoConstraints = false
        switcherSizeControl.segmentStyle = .rounded
        switcherSizeControl.controlSize = .regular
        switcherSizeControl.target = self
        switcherSizeControl.action = #selector(switcherSizeChanged(_:))
        if switcherSizeControl.segmentCount == 0 {
            switcherSizeControl.segmentCount = 4
            switcherSizeControl.setLabel("Small", forSegment: 0)
            switcherSizeControl.setLabel("Medium", forSegment: 1)
            switcherSizeControl.setLabel("Large", forSegment: 2)
            switcherSizeControl.setLabel("Auto", forSegment: 3)
        }
        syncSwitcherSizeSelection()
        return switcherSizeControl
    }

    @objc private func switcherSizeChanged(_ sender: NSSegmentedControl) {
        let preset: SwitcherSizePreset
        switch sender.selectedSegment {
        case 0: preset = .small
        case 1: preset = .medium
        case 2: preset = .large
        default: preset = .auto
        }
        AppSettings.shared.switcherSizePreset = preset
    }

    @objc private func syncSwitcherSizeSelection() {
        let selectedSegment: Int
        switch AppSettings.shared.switcherSizePreset {
        case .small: selectedSegment = 0
        case .medium: selectedSegment = 1
        case .large: selectedSegment = 2
        case .auto: selectedSegment = 3
        }
        switcherSizeControl.selectedSegment = selectedSegment
    }

    private func makeSwitcherThemeControl() -> NSSegmentedControl {
        switcherThemeControl.translatesAutoresizingMaskIntoConstraints = false
        switcherThemeControl.segmentStyle = .rounded
        switcherThemeControl.controlSize = .regular
        switcherThemeControl.target = self
        switcherThemeControl.action = #selector(switcherThemeChanged(_:))
        if switcherThemeControl.segmentCount == 0 {
            switcherThemeControl.segmentCount = 3
            switcherThemeControl.setLabel("Light", forSegment: 0)
            switcherThemeControl.setLabel("Dark", forSegment: 1)
            switcherThemeControl.setLabel("System", forSegment: 2)
        }
        syncSwitcherThemeSelection()
        return switcherThemeControl
    }

    private func makeSwitcherReleaseActionPopup() -> NSPopUpButton {
        switcherReleaseActionPopup.translatesAutoresizingMaskIntoConstraints = false
        switcherReleaseActionPopup.controlSize = .regular
        switcherReleaseActionPopup.target = self
        switcherReleaseActionPopup.action = #selector(switcherReleaseActionChanged(_:))
        switcherReleaseActionPopup.widthAnchor.constraint(equalToConstant: 200).isActive = true
        if switcherReleaseActionPopup.numberOfItems == 0 {
            switcherReleaseActionPopup.addItems(withTitles: ["Focus selected window", "Keep Open"])
        }
        syncSwitcherReleaseActionSelection()
        return switcherReleaseActionPopup
    }

    private func makeSwitcherPreviewSelectedWindowToggle() -> NSSwitch {
        switcherPreviewSelectedWindowToggle.translatesAutoresizingMaskIntoConstraints = false
        switcherPreviewSelectedWindowToggle.controlSize = .mini
        switcherPreviewSelectedWindowToggle.target = self
        switcherPreviewSelectedWindowToggle.action = #selector(
            switcherPreviewSelectedWindowChanged(_:))
        syncSwitcherPreviewSelectedWindowSelection()
        return switcherPreviewSelectedWindowToggle
    }

    @objc private func switcherThemeChanged(_ sender: NSSegmentedControl) {
        let preset: SwitcherThemePreset
        switch sender.selectedSegment {
        case 0: preset = .light
        case 1: preset = .dark
        default: preset = .system
        }
        AppSettings.shared.switcherThemePreset = preset
    }

    @objc private func switcherReleaseActionChanged(_ sender: NSPopUpButton) {
        switch sender.indexOfSelectedItem {
        case 1:
            AppSettings.shared.switcherReleaseAction = .keepOpen
        default:
            AppSettings.shared.switcherReleaseAction = .focusSelectedWindow
        }
    }

    @objc private func switcherPreviewSelectedWindowChanged(_ sender: NSSwitch) {
        AppSettings.shared.switcherPreviewSelectedWindow = (sender.state == .on)
    }

    @objc private func syncSwitcherThemeSelection() {
        let selectedSegment: Int
        switch AppSettings.shared.switcherThemePreset {
        case .light: selectedSegment = 0
        case .dark: selectedSegment = 1
        case .system: selectedSegment = 2
        }
        switcherThemeControl.selectedSegment = selectedSegment
    }

    @objc private func syncSwitcherReleaseActionSelection() {
        switch AppSettings.shared.switcherReleaseAction {
        case .focusSelectedWindow:
            switcherReleaseActionPopup.selectItem(at: 0)
        case .keepOpen:
            switcherReleaseActionPopup.selectItem(at: 1)
        }
    }

    @objc private func syncSwitcherPreviewSelectedWindowSelection() {
        switcherPreviewSelectedWindowToggle.state =
            AppSettings.shared.switcherPreviewSelectedWindow ? .on : .off
    }

    private func makeAppearancePopup(
        titles: [String],
        selectedIndex: Int,
        width: CGFloat
    ) -> NSPopUpButton {
        let popup = NSPopUpButton()
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.addItems(withTitles: titles)
        popup.selectItem(at: selectedIndex)
        popup.controlSize = .regular
        popup.widthAnchor.constraint(equalToConstant: width).isActive = true
        return popup
    }

    private func makeAppearanceSwitch(isOn: Bool) -> NSSwitch {
        let toggle = NSSwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.controlSize = .mini
        toggle.state = isOn ? .on : .off
        return toggle
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
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
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

    @objc private func shortcutModifierChanged(_ sender: NSPopUpButton) {
        shortcutChanged(sender)
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

    func windowDidResize(_ notification: Notification) {
        layoutTrafficButtons()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        layoutTrafficButtons()
    }

    @objc private func resetSettingsAndRestart() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Reset settings is not implemented yet."
        alert.addButton(withTitle: "OK")
        alert.runModal()
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

    private func layoutTrafficButtons() {
        guard let window,
            let closeButton = window.standardWindowButton(.closeButton),
            let miniaturizeButton = window.standardWindowButton(.miniaturizeButton),
            let zoomButton = window.standardWindowButton(.zoomButton),
            let buttonContainer = closeButton.superview
        else {
            return
        }

        let topInset: CGFloat = 18
        let leadingInset: CGFloat = 18
        let spacing: CGFloat = 8
        let y = buttonContainer.bounds.height - topInset - closeButton.frame.height

        closeButton.setFrameOrigin(NSPoint(x: leadingInset, y: y))
        miniaturizeButton.setFrameOrigin(
            NSPoint(x: closeButton.frame.maxX + spacing, y: y)
        )
        zoomButton.setFrameOrigin(
            NSPoint(x: miniaturizeButton.frame.maxX + spacing, y: y)
        )
    }
}
