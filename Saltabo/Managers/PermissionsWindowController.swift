import AppKit

private final class PermissionStatusPill: NSView {
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.alignment = .center

        addSubview(label)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: 96),
            heightAnchor.constraint(equalToConstant: 26),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func apply(text: String, foreground: NSColor, background: NSColor) {
        label.stringValue = text
        label.textColor = foreground
        layer?.backgroundColor = background.cgColor
    }
}

private final class PermissionCardView: NSView {
    private let iconContainer = NSView()
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let descriptionField = NSTextField(wrappingLabelWithString: "")
    private let openButton: NSButton
    private let pill = PermissionStatusPill(frame: .zero)

    init(title: String, description: String, buttonTitle: String) {
        openButton = NSButton(title: buttonTitle, target: nil, action: nil)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 9
        iconContainer.layer?.masksToBounds = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.symbolConfiguration = .init(pointSize: 24, weight: .semibold)
        iconView.contentTintColor = .labelColor
        iconContainer.addSubview(iconView)

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.font = .systemFont(ofSize: 16, weight: .semibold)
        titleField.stringValue = title

        descriptionField.translatesAutoresizingMaskIntoConstraints = false
        descriptionField.font = .systemFont(ofSize: 13)
        descriptionField.textColor = .secondaryLabelColor
        descriptionField.maximumNumberOfLines = 0
        descriptionField.stringValue = description

        openButton.bezelStyle = .rounded
        openButton.translatesAutoresizingMaskIntoConstraints = false

        let headerRow = NSStackView(views: [iconContainer, titleField])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 12
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        let footerRow = NSStackView(views: [openButton, pill])
        footerRow.orientation = .horizontal
        footerRow.alignment = .centerY
        footerRow.spacing = 12
        footerRow.distribution = .fillEqually
        footerRow.translatesAutoresizingMaskIntoConstraints = false

        addSubview(headerRow)
        addSubview(descriptionField)
        addSubview(footerRow)

        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            headerRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            headerRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),

            iconContainer.widthAnchor.constraint(equalToConstant: 28),
            iconContainer.heightAnchor.constraint(equalToConstant: 28),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            descriptionField.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 10),
            descriptionField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            descriptionField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),

            footerRow.topAnchor.constraint(equalTo: descriptionField.bottomAnchor, constant: 14),
            footerRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            footerRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            footerRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setButtonTarget(_ target: AnyObject?, action: Selector) {
        openButton.target = target
        openButton.action = action
    }

    func configure(
        icon: NSImage?,
        iconTint: NSColor,
        iconBackground: NSColor,
        granted: Bool,
        required: Bool
    ) {
        iconView.image = icon
        iconView.contentTintColor = iconTint
        iconContainer.layer?.backgroundColor = iconBackground.cgColor

        if granted {
            layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.10).cgColor
            pill.apply(
                text: "Granted",
                foreground: NSColor.systemGreen.blended(withFraction: 0.2, of: .labelColor)
                    ?? .systemGreen,
                background: NSColor.systemGreen.withAlphaComponent(0.14)
            )
        } else if required {
            layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.10).cgColor
            pill.apply(
                text: "Not Allowed",
                foreground: .systemRed,
                background: NSColor.systemRed.withAlphaComponent(0.14)
            )
        } else {
            layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.12).cgColor
            pill.apply(
                text: "Optional",
                foreground: NSColor.systemOrange,
                background: NSColor.systemYellow.withAlphaComponent(0.18)
            )
        }
    }
}

final class PermissionsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = PermissionsWindowController()

    private let accessibilityCard = PermissionCardView(
        title: "Accessibility",
        description: "Needed to focus windows after you release the shortcut.",
        buttonTitle: "Open Accessibility Settings"
    )
    private let screenRecordingCard = PermissionCardView(
        title: "Screen Recording",
        description: "Needed to read visible windows and build the switcher list.",
        buttonTitle: "Open Screen Recording Settings"
    )
    private let cardsStack = NSStackView()
    private var accessibilityCardWidthConstraint: NSLayoutConstraint?
    private var screenRecordingCardWidthConstraint: NSLayoutConstraint?

    private var onContinue: (() -> Void)?
    private var didContinue = false

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 292),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        window.title = "Saltabo needs permissions"
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = buildContentView()

        accessibilityCard.setButtonTarget(self, action: #selector(openAccessibilitySettings))
        screenRecordingCard.setButtonTarget(self, action: #selector(openScreenRecordingSettings))
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshStatus),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(refreshStatus),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        nil
    }

    func presentIfNeeded(onContinue: @escaping () -> Void) -> Bool {
        let snapshot = AccessibilityService.shared.currentPermissionSnapshot()
        guard !(snapshot.accessibilityGranted && snapshot.screenRecordingGranted) else {
            return false
        }
        if !snapshot.screenRecordingGranted {
            _ = AccessibilityService.shared.requestScreenRecordingPermission()
        }

        self.onContinue = onContinue
        self.didContinue = false
        refreshStatus()
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    private func buildContentView() -> NSView {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView(image: NSApp.applicationIconImage)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown

        let title = NSTextField(labelWithString: "Saltabo needs some permissions")
        title.font = .systemFont(ofSize: 16, weight: .bold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = NSTextField(
            wrappingLabelWithString:
                "Enable the required permission below before Saltabo starts listening for keyboard shortcuts."
        )
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 0
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView(views: [iconView, title])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 16
        header.translatesAutoresizingMaskIntoConstraints = false

        cardsStack.orientation = .vertical
        cardsStack.alignment = .leading
        cardsStack.spacing = 14
        cardsStack.translatesAutoresizingMaskIntoConstraints = false
        cardsStack.addArrangedSubview(accessibilityCard)
        cardsStack.addArrangedSubview(screenRecordingCard)

        root.addSubview(header)
        root.addSubview(subtitle)
        root.addSubview(cardsStack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            header.topAnchor.constraint(equalTo: root.topAnchor, constant: 28),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            header.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -28),

            subtitle.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 14),
            subtitle.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            subtitle.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),

            cardsStack.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 22),
            cardsStack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            cardsStack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            cardsStack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -28),
        ])

        accessibilityCardWidthConstraint = accessibilityCard.widthAnchor.constraint(
            equalTo: cardsStack.widthAnchor)
        accessibilityCardWidthConstraint?.isActive = true
        screenRecordingCardWidthConstraint = screenRecordingCard.widthAnchor.constraint(
            equalTo: cardsStack.widthAnchor)
        screenRecordingCardWidthConstraint?.isActive = true

        return root
    }

    @objc private func refreshStatus() {
        let snapshot = AccessibilityService.shared.currentPermissionSnapshot()
        accessibilityCard.configure(
            icon: NSImage(systemSymbolName: "accessibility", accessibilityDescription: nil),
            iconTint: .systemBlue,
            iconBackground: NSColor.systemBlue.withAlphaComponent(0.14),
            granted: snapshot.accessibilityGranted,
            required: true
        )
        screenRecordingCard.configure(
            icon: NSImage(systemSymbolName: "display", accessibilityDescription: nil),
            iconTint: .systemPurple,
            iconBackground: NSColor.systemPurple.withAlphaComponent(0.14),
            granted: snapshot.screenRecordingGranted,
            required: true
        )
        if snapshot.accessibilityGranted && snapshot.screenRecordingGranted && !didContinue {
            didContinue = true
            window?.orderOut(nil)
            NSApp.setActivationPolicy(.accessory)
            onContinue?()
            onContinue = nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard !didContinue else { return }
        let snapshot = AccessibilityService.shared.currentPermissionSnapshot()
        if !(snapshot.accessibilityGranted && snapshot.screenRecordingGranted) {
            NSApp.terminate(nil)
        }
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityService.shared.openAccessibilitySettings()
    }

    @objc private func openScreenRecordingSettings() {
        _ = AccessibilityService.shared.requestScreenRecordingPermission()
        AccessibilityService.shared.openScreenRecordingSettings()
    }
}
