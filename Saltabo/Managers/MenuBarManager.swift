import AppKit

final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var hasInstalledObservers = false

    func setup() {
        if !hasInstalledObservers {
            hasInstalledObservers = true
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
        }
        applyMenubarVisibility()
    }

    /// Removes the menu bar icon (used when trial expires and core features must stop).
    func tearDownPresentation() {
        removeStatusItem()
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
            makeMenuItems(
                title: "About Saltabo...",
                action: #selector(openAbout),
                keyEquivalent: "",
                symbolName: "info.circle",
            )
        )
        menu.addItem(
            makeMenuItems(
                title: "Check for Updates...",
                action: #selector(checkForUpdates),
                keyEquivalent: "",
                symbolName: "arrow.down.circle",
            )
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            makeMenuItems(
                title: "Settings...",
                action: #selector(openSettings),
                keyEquivalent: ",",
                symbolName: "gearshape",
            )
        )
        menu.addItem(
            makeMenuItems(
                title: "Manage License...",
                action: #selector(openLicenseSettings),
                keyEquivalent: "",
                symbolName: "key.fill",
            )
        )
        menu.addItem(
            makeMenuItems(
                title: "Check permissions...",
                action: #selector(checkPermissions),
                keyEquivalent: "",
                symbolName: "accessibility",
            )
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            makeMenuItems(
                title: "Send Feedback",
                action: #selector(sendFeedback),
                keyEquivalent: "",
                symbolName: "paperplane",
            )
        )
        menu.addItem(
            makeMenuItems(
                title: "Request Feature...",
                action: #selector(requestFeature),
                keyEquivalent: "",
                symbolName: "lightbulb",
            )
        )
        menu.addItem(
            makeMenuItems(
                title: "Report Bug",
                action: #selector(reportBug),
                keyEquivalent: "",
                symbolName: "exclamationmark.triangle",
            )
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            makeMenuItems(
                title: "Quit Saltabo",
                action: #selector(quit),
                keyEquivalent: "q",
                symbolName: "xmark",
            )
        )
        menu.items.forEach { $0.target = self }

        item.menu = menu
        statusItem = item
    }

    private func makeMenuItems(
        title str: String, action selector: Selector,
        keyEquivalent charCode: String,
        symbolName: String? = nil,
    )
        -> NSMenuItem
    {
        let item = NSMenuItem(title: str, action: selector, keyEquivalent: charCode)
        if let symbolName {
            item.image = menuSymbol(named: symbolName)
        }
        return item
    }

    private func menuSymbol(named symbolName: String) -> NSImage? {
        let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        let configured = base?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 12, weight: .regular))
        configured?.isTemplate = true
        return configured
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

    @objc private func openLicenseSettings() {
        DispatchQueue.main.async {
            SettingsWindowController.shared.showSettings()
        }
    }

    @objc private func openAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let shortVersion =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0"
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

    @objc private func checkPermissions() {
        PermissionsWindowController.shared.presentForManualCheck()
    }

    @objc private func sendFeedback() {
        FeedbackWindowController.shared.showWindow()
    }

    @objc private func requestFeature() {
        guard
            let url = URL(
                string:
                    "https://github.com/saltabo/saltabo/issues/new?template=feature_request.md")
        else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func reportBug() {
        BugReportWindowController.shared.showWindow()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private final class FeedbackWindowController: NSWindowController, NSWindowDelegate,
    NSTextViewDelegate, NSTextFieldDelegate
{
    static let shared = FeedbackWindowController()

    private let adminEmail = "saltaboapp@pm.me"
    private let messageTextView = NSTextView()
    private let messagePlaceholderLabel = NSTextField(
        labelWithString: "I think the app could be improved with..."
    )
    private let emailField = VerticallyCenteredTextField()
    private let sendButton = NSButton(title: "Send", target: nil, action: nil)

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        window.title = "Saltabo Feedback"
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = buildContentView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func showWindow() {
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self.messageTextView)
        }
    }

    private func buildContentView() -> NSView {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Send Feedback")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)

        let subtitleLabel = NSTextField(
            labelWithString: "What's on your mind? An issue, suggestion, or a nice note?"
        )
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.alignment = .center
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor

        let textContainer = NSScrollView()
        textContainer.translatesAutoresizingMaskIntoConstraints = false
        textContainer.hasVerticalScroller = false
        textContainer.hasHorizontalScroller = false
        textContainer.drawsBackground = true
        textContainer.backgroundColor = .white
        textContainer.borderType = .lineBorder
        textContainer.wantsLayer = true
        textContainer.layer?.cornerRadius = 8
        textContainer.layer?.borderWidth = 1.5
        textContainer.layer?.borderColor =
            NSColor(
                calibratedWhite: 0.9,
                alpha: 1
            ).cgColor
        textContainer.layer?.masksToBounds = true

        messageTextView.translatesAutoresizingMaskIntoConstraints = true
        messageTextView.isRichText = false
        messageTextView.isEditable = true
        messageTextView.isSelectable = true
        messageTextView.allowsUndo = true
        messageTextView.font = .systemFont(ofSize: 13)
        messageTextView.drawsBackground = false
        messageTextView.backgroundColor = .clear
        messageTextView.delegate = self
        messageTextView.textContainerInset = NSSize(width: 8, height: 10)
        messageTextView.frame = NSRect(origin: .zero, size: textContainer.contentSize)
        messageTextView.autoresizingMask = [.width]
        textContainer.documentView = messageTextView
        messageTextView.minSize = NSSize(width: 0, height: 0)
        messageTextView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        messageTextView.isVerticallyResizable = true
        messageTextView.isHorizontallyResizable = false
        messageTextView.textContainer?.widthTracksTextView = true
        messageTextView.textContainer?.containerSize = NSSize(
            width: textContainer.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )

        messagePlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false
        messagePlaceholderLabel.font = .systemFont(ofSize: 13, weight: .regular)
        messagePlaceholderLabel.textColor = .placeholderTextColor
        messagePlaceholderLabel.isEditable = false
        messagePlaceholderLabel.isSelectable = false
        messagePlaceholderLabel.isBezeled = false
        messagePlaceholderLabel.drawsBackground = false
        messagePlaceholderLabel.lineBreakMode = .byTruncatingTail
        messageTextView.addSubview(messagePlaceholderLabel)

        emailField.translatesAutoresizingMaskIntoConstraints = false
        emailField.placeholderString = "Email (optional)"
        emailField.delegate = self
        emailField.font = .systemFont(ofSize: 13)
        emailField.isBezeled = false
        emailField.drawsBackground = true
        emailField.backgroundColor = .white
        emailField.isEditable = true
        emailField.isSelectable = true
        emailField.isEnabled = true
        emailField.wantsLayer = true
        emailField.focusRingType = .none
        emailField.layer?.cornerRadius = 6
        emailField.layer?.borderWidth = 1
        emailField.layer?.borderColor =
            NSColor(
                calibratedWhite: 0.72,
                alpha: 1
            ).cgColor

        let mailHintLabel = NSTextField(
            labelWithString: "Note: Please open the Mail app first before sending feedback."
        )
        mailHintLabel.translatesAutoresizingMaskIntoConstraints = false
        mailHintLabel.alignment = .center
        mailHintLabel.font = .systemFont(ofSize: 12, weight: .regular)
        mailHintLabel.textColor = .secondaryLabelColor

        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.bezelStyle = .rounded
        sendButton.controlSize = .regular
        sendButton.target = self
        sendButton.action = #selector(sendFeedbackEmail)
        sendButton.isEnabled = false

        root.addSubview(titleLabel)
        root.addSubview(subtitleLabel)
        root.addSubview(emailField)
        root.addSubview(textContainer)
        root.addSubview(mailHintLabel)
        root.addSubview(sendButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: 28),
            titleLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),

            emailField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            emailField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            emailField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            emailField.heightAnchor.constraint(equalToConstant: 28),

            textContainer.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 8),
            textContainer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            textContainer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            textContainer.heightAnchor.constraint(equalToConstant: 250),
            messagePlaceholderLabel.topAnchor.constraint(
                equalTo: messageTextView.topAnchor, constant: 10),
            messagePlaceholderLabel.leadingAnchor.constraint(
                equalTo: messageTextView.leadingAnchor, constant: 12
            ),
            messagePlaceholderLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: messageTextView.trailingAnchor, constant: -12
            ),

            mailHintLabel.topAnchor.constraint(equalTo: textContainer.bottomAnchor, constant: 8),
            mailHintLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            mailHintLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),

            sendButton.topAnchor.constraint(equalTo: mailHintLabel.bottomAnchor, constant: 12),
            sendButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            sendButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 86),
            sendButton.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -24),
        ])

        syncSendButtonEnabled()
        return root
    }

    func textDidChange(_ notification: Notification) {
        syncSendButtonEnabled()
    }

    func controlTextDidChange(_ obj: Notification) {
        syncSendButtonEnabled()
    }

    private func syncSendButtonEnabled() {
        let hasMessage = !messageTextView.string.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
        sendButton.isEnabled = hasMessage
        messagePlaceholderLabel.isHidden = hasMessage
    }

    @objc private func sendFeedbackEmail() {
        let message = messageTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        let shortVersion =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0"
        let buildVersion =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        let email = emailField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        let body = """
            \(message)

            ---
            Follow-up email: \(email.isEmpty ? "(not provided)" : email)
            App version: \(shortVersion) (\(buildVersion))
            macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
            """
        openMailtoInAppleMail(subject: "Saltabo Feedback", body: body)
    }

    private func openMailtoInAppleMail(subject: String, body: String) {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = adminEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]

        guard let url = components.url else {
            presentOpenMailFailedAlert()
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        if let mailAppURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.mail")
        {
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: mailAppURL,
                configuration: configuration
            ) { [weak self] _, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if error != nil {
                        self.openMailtoWithDefaultApp(url: url)
                        return
                    }
                    self.window?.orderOut(nil)
                    NSApp.setActivationPolicy(.accessory)
                }
            }
            return
        }

        openMailtoWithDefaultApp(url: url)
    }

    private func openMailtoWithDefaultApp(url: URL) {
        NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration()) {
            [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if error != nil {
                    self.presentOpenMailFailedAlert()
                    return
                }
                self.window?.orderOut(nil)
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    private func presentOpenMailFailedAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Unable to open Mail."
        alert.informativeText =
            "Please ensure Apple Mail is installed and set up, then try again."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

}

private final class BugReportWindowController: NSWindowController, NSWindowDelegate {
    static let shared = BugReportWindowController()

    private let adminEmail = "saltaboapp@pm.me"
    private let statusLabel = NSTextField(labelWithString: "Diagnostic report generated.")
    private let detailLabel = NSTextField(
        labelWithString: "Do you want to review the contents\nbefore uploading it?"
    )
    private let reviewButton = NSButton(title: "Review", target: nil, action: nil)
    private let uploadButton = NSButton(title: "Upload", target: nil, action: nil)
    private var reportURL: URL?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        window.title = "Report a Bug"
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = buildContentView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func showWindow() {
        regenerateReport()
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContentView() -> NSView {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(
            systemSymbolName: "questionmark.circle.fill",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(.init(pointSize: 42, weight: .regular))
        iconView.contentTintColor = NSColor(calibratedWhite: 0.2, alpha: 1)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.alignment = .center
        statusLabel.font = .systemFont(ofSize: 13, weight: .regular)
        statusLabel.textColor = .labelColor

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.alignment = .center
        detailLabel.font = .systemFont(ofSize: 13, weight: .regular)
        detailLabel.textColor = .labelColor
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 2

        reviewButton.translatesAutoresizingMaskIntoConstraints = false
        reviewButton.bezelStyle = .rounded
        reviewButton.controlSize = .large
        reviewButton.target = self
        reviewButton.action = #selector(reviewReport)

        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        uploadButton.bezelStyle = .rounded
        uploadButton.controlSize = .large
        uploadButton.bezelColor = .systemBlue
        uploadButton.target = self
        uploadButton.action = #selector(uploadReport)

        root.addSubview(iconView)
        root.addSubview(statusLabel)
        root.addSubview(detailLabel)
        root.addSubview(reviewButton)
        root.addSubview(uploadButton)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: root.topAnchor, constant: 58),
            iconView.widthAnchor.constraint(equalToConstant: 42),
            iconView.heightAnchor.constraint(equalToConstant: 42),

            statusLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            statusLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),

            detailLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 14),
            detailLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 26),
            detailLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -26),

            reviewButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 22),
            reviewButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18),
            reviewButton.widthAnchor.constraint(equalToConstant: 72),

            uploadButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -22),
            uploadButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18),
            uploadButton.widthAnchor.constraint(equalToConstant: 72),
        ])

        return root
    }

    private func regenerateReport() {
        do {
            let report = buildDiagnosticReport()
            let tempDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("Saltabo", isDirectory: true)
            try FileManager.default.createDirectory(
                at: tempDirectory,
                withIntermediateDirectories: true
            )
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let fileURL = tempDirectory.appendingPathComponent(
                "saltabo-diagnostic-\(timestamp).txt"
            )
            try report.write(to: fileURL, atomically: true, encoding: .utf8)
            reportURL = fileURL
            uploadButton.isEnabled = true
            reviewButton.isEnabled = true
        } catch {
            reportURL = nil
            uploadButton.isEnabled = false
            reviewButton.isEnabled = false
            presentReportError(message: "Unable to generate diagnostic report.")
        }
    }

    private func buildDiagnosticReport() -> String {
        let settings = AppSettings.shared
        let permissions = AccessibilityService.shared.currentPermissionSnapshot()
        let shortVersion =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0"
        let buildVersion =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown"
        let timezone = TimeZone.current.identifier
        let locale = Locale.current.identifier
        let defaultsDump = diagnosticUserDefaultsDump()

        return """
            Saltabo Diagnostic Report
            Generated: \(ISO8601DateFormatter().string(from: Date()))

            App
            - Version: \(shortVersion) (\(buildVersion))
            - Bundle ID: \(bundleIdentifier)

            System
            - macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
            - Locale: \(locale)
            - Time Zone: \(timezone)

            Permissions
            - Accessibility: \(permissions.accessibilityGranted)
            - Screen Recording: \(permissions.screenRecordingGranted)

            Settings
            - Shortcut: \(settings.switcherShortcut.rawValue)
            - Trigger Key Code: \(settings.switcherTriggerKeyCode)
            - Display Style: \(settings.switcherDisplayStyle.rawValue)
            - Size Preset: \(settings.switcherSizePreset.rawValue)
            - Theme Preset: \(settings.switcherThemePreset.rawValue)
            - Release Action: \(settings.switcherReleaseAction.rawValue)
            - Preview Selected Window: \(settings.switcherPreviewSelectedWindow)
            - Application Scope: \(settings.switcherApplicationScope.rawValue)
            - Screen Scope: \(settings.switcherScreenScope.rawValue)
            - Minimized Windows: \(settings.switcherMinimizedWindowsVisibility.rawValue)
            - Hidden Windows: \(settings.switcherHiddenWindowsVisibility.rawValue)
            - Fullscreen Windows: \(settings.switcherFullscreenWindowsVisibility.rawValue)
            - Order Preference: \(settings.switcherOrderPreference.rawValue)
            - Start At Login: \(settings.startAtLoginEnabled)
            - Menubar Icon Style: \(settings.menubarIconStyle.rawValue)
            - Menubar Icon Visible: \(settings.menubarIconVisible)
            - Capture Windows In Background: \(settings.captureWindowsInBackground)
            - Language: \(settings.appLanguage.rawValue)
            - Update Policy: \(settings.updateCheckPolicy.rawValue)
            - Crash Reports Policy: \(settings.crashReportsPolicy.rawValue)
            - License Status: \(settings.licenseStatus.rawValue)
            - License Activated At: \(settings.licenseActivatedAt?.description ?? "nil")

            UserDefaults
            \(defaultsDump)
            """
    }

    private func diagnosticUserDefaultsDump() -> String {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier,
            let defaults = UserDefaults.standard.persistentDomain(forName: bundleIdentifier)
        else {
            return "- No persistent domain found."
        }

        let relevantEntries =
            defaults
            .filter { $0.key.hasPrefix("Saltabo.") }
            .sorted { $0.key < $1.key }

        guard !relevantEntries.isEmpty else {
            return "- No Saltabo-specific defaults found."
        }

        return
            relevantEntries
            .map { "- \($0.key): \($0.value)" }
            .joined(separator: "\n")
    }

    @objc private func reviewReport() {
        guard let reportURL else {
            presentReportError(message: "Diagnostic report is not available.")
            return
        }
        NSWorkspace.shared.open(reportURL)
    }

    @objc private func uploadReport() {
        guard let reportURL else {
            presentReportError(message: "Diagnostic report is not available.")
            return
        }

        let reportContents: String
        do {
            reportContents = try String(contentsOf: reportURL, encoding: .utf8)
        } catch {
            presentReportError(message: "Unable to read the diagnostic report.")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let title = "Bug report: \(formatter.string(from: Date()))"
        var components = URLComponents(
            string: "https://github.com/saltabo/saltabo/issues/new"
        )
        components?.queryItems = [
            URLQueryItem(name: "template", value: "bug_report.yml"),
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "diag", value: reportContents),
        ]

        guard let issueURL = components?.url else {
            presentReportError(message: "Unable to create the GitHub issue URL.")
            return
        }

        guard NSWorkspace.shared.open(issueURL) else {
            presentReportError(message: "Unable to open GitHub issue creation page.")
            return
        }

        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    private func presentReportError(message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

private final class VerticallyCenteredTextField: NSTextField {
    override func awakeFromNib() {
        super.awakeFromNib()
        configureCell()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureCell()
    }

    private func configureCell() {
        let centeredCell = VerticallyCenteredTextFieldCell(textCell: stringValue)
        centeredCell.horizontalPadding = 10
        centeredCell.isBordered = false
        centeredCell.isBezeled = false
        centeredCell.drawsBackground = false
        cell = centeredCell
    }
}

private final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    var horizontalPadding: CGFloat = 0

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        let paddedRect = rect.insetBy(dx: horizontalPadding, dy: 0)
        var titleRect = super.titleRect(forBounds: paddedRect)
        let titleSize = cellSize(forBounds: paddedRect)
        titleRect.origin.y += max(0, (titleRect.height - titleSize.height) / 2)
        titleRect.size.height = min(titleRect.height, titleSize.height)
        return titleRect
    }

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        titleRect(forBounds: rect)
    }

    override func edit(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        event: NSEvent?
    ) {
        super.edit(
            withFrame: titleRect(forBounds: rect),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            event: event
        )
    }

    override func select(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        start selStart: Int,
        length selLength: Int
    ) {
        super.select(
            withFrame: titleRect(forBounds: rect),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            start: selStart,
            length: selLength
        )
    }
}
