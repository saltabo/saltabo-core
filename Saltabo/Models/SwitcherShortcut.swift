import AppKit
import CoreGraphics

enum SwitcherDisplayStyle: String, CaseIterable {
    case thumbnails
    case appIcons
    case list
}

enum SwitcherSizePreset: String, CaseIterable {
    case small
    case medium
    case large
    case auto
}

enum SwitcherThemePreset: String, CaseIterable {
    case light
    case dark
    case system
}

enum SwitcherReleaseAction: String, CaseIterable {
    case focusSelectedWindow
    case keepOpen
}

enum SwitcherApplicationScope: String, CaseIterable {
    case allApps
    case activeAppOnly
    case nonActiveApps
}

enum SwitcherScreenScope: String, CaseIterable {
    case currentScreenOnly
    case allScreens
}

enum SwitcherMinimizedWindowsVisibility: String, CaseIterable {
    case show
    case hide
}

enum SwitcherHiddenWindowsVisibility: String, CaseIterable {
    case show
    case hide
}

enum SwitcherFullscreenWindowsVisibility: String, CaseIterable {
    case show
    case hide
}

enum SwitcherOrderPreference: String, CaseIterable {
    case recentlyFocusedFirst
    case recentlyOpenedFirst
    case nameAZ
    case nameZA
}

enum MenubarIconStyle: String, CaseIterable {
    case `default`
    case minimal
    case classic
}

enum AppLanguage: String, CaseIterable {
    case system
    case english
    case vietnamese
}

enum UpdateCheckPolicy: String, CaseIterable {
    case periodically
    case manuallyOnly
}

enum CrashReportsPolicy: String, CaseIterable {
    case ask
    case always
    case never
}

enum LicenseStatus: String {
    case inactive
    case active
}

enum SwitcherShortcut: String, CaseIterable {
    case commandTab
    case optionTab
    case controlTab

    var displayName: String {
        switch self {
        case .commandTab:
            return "⌘ + Tab"
        case .optionTab:
            return "⌥ + Tab"
        case .controlTab:
            return "⌃ + Tab"
        }
    }

    var modifierSymbol: String {
        switch self {
        case .commandTab:
            return "⌘"
        case .optionTab:
            return "⌥"
        case .controlTab:
            return "⌃"
        }
    }

    var modifierFlags: CGEventFlags {
        switch self {
        case .commandTab:
            return .maskCommand
        case .optionTab:
            return .maskAlternate
        case .controlTab:
            return .maskControl
        }
    }

    var modifierReleaseKeyCodes: Set<Int64> {
        switch self {
        case .commandTab:
            return [54, 55]
        case .optionTab:
            return [58, 61]
        case .controlTab:
            return [59, 62]
        }
    }

    func matches(tabKeyCode: Int64, flags: CGEventFlags) -> Bool {
        tabKeyCode == AppSettings.shared.switcherTriggerKeyCode && flags.contains(modifierFlags)
    }

    func matchesModifierRelease(keyCode: Int64, flags: CGEventFlags) -> Bool {
        modifierReleaseKeyCodes.contains(keyCode) && !flags.contains(modifierFlags)
    }
}

extension Notification.Name {
    static let switcherShortcutDidChange = Notification.Name("Saltabo.switcherShortcutDidChange")
    static let switcherTriggerKeyCodeDidChange = Notification.Name("Saltabo.switcherTriggerKeyCodeDidChange")
    static let switcherDisplayStyleDidChange = Notification.Name("Saltabo.switcherDisplayStyleDidChange")
    static let switcherSizePresetDidChange = Notification.Name("Saltabo.switcherSizePresetDidChange")
    static let switcherThemePresetDidChange = Notification.Name("Saltabo.switcherThemePresetDidChange")
    static let switcherReleaseActionDidChange = Notification.Name("Saltabo.switcherReleaseActionDidChange")
    static let switcherPreviewSelectedWindowDidChange = Notification.Name("Saltabo.switcherPreviewSelectedWindowDidChange")
    static let switcherApplicationScopeDidChange = Notification.Name("Saltabo.switcherApplicationScopeDidChange")
    static let switcherScreenScopeDidChange = Notification.Name("Saltabo.switcherScreenScopeDidChange")
    static let switcherMinimizedWindowsVisibilityDidChange = Notification.Name(
        "Saltabo.switcherMinimizedWindowsVisibilityDidChange")
    static let switcherHiddenWindowsVisibilityDidChange = Notification.Name(
        "Saltabo.switcherHiddenWindowsVisibilityDidChange")
    static let switcherFullscreenWindowsVisibilityDidChange = Notification.Name(
        "Saltabo.switcherFullscreenWindowsVisibilityDidChange")
    static let switcherOrderPreferenceDidChange = Notification.Name(
        "Saltabo.switcherOrderPreferenceDidChange")
    static let menubarIconStyleDidChange = Notification.Name("Saltabo.menubarIconStyleDidChange")
    static let menubarIconVisibilityDidChange = Notification.Name(
        "Saltabo.menubarIconVisibilityDidChange")
    static let appLanguageDidChange = Notification.Name("Saltabo.appLanguageDidChange")
    static let updateCheckPolicyDidChange = Notification.Name("Saltabo.updateCheckPolicyDidChange")
    static let crashReportsPolicyDidChange = Notification.Name("Saltabo.crashReportsPolicyDidChange")
    static let licenseStatusDidChange = Notification.Name("Saltabo.licenseStatusDidChange")
    static let switcherAvailabilityDidChange = Notification.Name(
        "Saltabo.switcherAvailabilityDidChange")
}

final class AppSettings {
    static let shared = AppSettings()

    private enum Keys {
        static let switcherShortcut = "Saltabo.switcherShortcut"
        static let switcherTriggerKeyCode = "Saltabo.switcherTriggerKeyCode"
        static let switcherDisplayStyle = "Saltabo.switcherDisplayStyle"
        static let switcherSizePreset = "Saltabo.switcherSizePreset"
        static let switcherThemePreset = "Saltabo.switcherThemePreset"
        static let switcherReleaseAction = "Saltabo.switcherReleaseAction"
        static let switcherPreviewSelectedWindow = "Saltabo.switcherPreviewSelectedWindow"
        static let switcherApplicationScope = "Saltabo.switcherApplicationScope"
        static let switcherScreenScope = "Saltabo.switcherScreenScope"
        static let switcherMinimizedWindowsVisibility = "Saltabo.switcherMinimizedWindowsVisibility"
        static let switcherHiddenWindowsVisibility = "Saltabo.switcherHiddenWindowsVisibility"
        static let switcherFullscreenWindowsVisibility = "Saltabo.switcherFullscreenWindowsVisibility"
        static let switcherOrderPreference = "Saltabo.switcherOrderPreference"
        static let startAtLoginEnabled = "Saltabo.startAtLoginEnabled"
        static let menubarIconStyle = "Saltabo.menubarIconStyle"
        static let menubarIconVisible = "Saltabo.menubarIconVisible"
        static let captureWindowsInBackground = "Saltabo.captureWindowsInBackground"
        static let appLanguage = "Saltabo.appLanguage"
        static let updateCheckPolicy = "Saltabo.updateCheckPolicy"
        static let crashReportsPolicy = "Saltabo.crashReportsPolicy"
        static let suppressMoveToApplicationsPrompt = "Saltabo.suppressMoveToApplicationsPrompt"
        static let licenseKey = "Saltabo.licenseKey"
        static let licenseStatus = "Saltabo.licenseStatus"
        static let licenseActivatedAt = "Saltabo.licenseActivatedAt"
        static let trialStartedAt = "Saltabo.trialStartedAt"
    }

    private let defaults = UserDefaults.standard

    private init() {}

    var switcherShortcut: SwitcherShortcut {
        get {
            guard
                let rawValue = defaults.string(forKey: Keys.switcherShortcut),
                let shortcut = SwitcherShortcut(rawValue: rawValue)
            else {
                return .commandTab
            }
            return shortcut
        }
        set {
            guard newValue != switcherShortcut else { return }
            defaults.set(newValue.rawValue, forKey: Keys.switcherShortcut)
            NotificationCenter.default.post(name: .switcherShortcutDidChange, object: newValue)
        }
    }

    var switcherTriggerKeyCode: Int64 {
        get {
            let stored = defaults.object(forKey: Keys.switcherTriggerKeyCode) as? Int
            return Int64(stored ?? 48)
        }
        set {
            guard newValue != switcherTriggerKeyCode else { return }
            defaults.set(Int(newValue), forKey: Keys.switcherTriggerKeyCode)
            NotificationCenter.default.post(name: .switcherTriggerKeyCodeDidChange, object: newValue)
        }
    }

    var switcherDisplayStyle: SwitcherDisplayStyle {
        get {
            guard
                let raw = defaults.string(forKey: Keys.switcherDisplayStyle),
                let style = SwitcherDisplayStyle(rawValue: raw)
            else {
                return .thumbnails
            }
            return style
        }
        set {
            guard newValue != switcherDisplayStyle else { return }
            defaults.set(newValue.rawValue, forKey: Keys.switcherDisplayStyle)
            NotificationCenter.default.post(name: .switcherDisplayStyleDidChange, object: newValue)
        }
    }

    var switcherSizePreset: SwitcherSizePreset {
        get {
            guard
                let raw = defaults.string(forKey: Keys.switcherSizePreset),
                let preset = SwitcherSizePreset(rawValue: raw)
            else {
                return .auto
            }
            return preset
        }
        set {
            guard newValue != switcherSizePreset else { return }
            defaults.set(newValue.rawValue, forKey: Keys.switcherSizePreset)
            NotificationCenter.default.post(name: .switcherSizePresetDidChange, object: newValue)
        }
    }

    var switcherThemePreset: SwitcherThemePreset {
        get {
            guard
                let raw = defaults.string(forKey: Keys.switcherThemePreset),
                let preset = SwitcherThemePreset(rawValue: raw)
            else {
                return .system
            }
            return preset
        }
        set {
            guard newValue != switcherThemePreset else { return }
            defaults.set(newValue.rawValue, forKey: Keys.switcherThemePreset)
            NotificationCenter.default.post(name: .switcherThemePresetDidChange, object: newValue)
        }
    }

    var switcherReleaseAction: SwitcherReleaseAction {
        get {
            guard
                let raw = defaults.string(forKey: Keys.switcherReleaseAction),
                let action = SwitcherReleaseAction(rawValue: raw)
            else {
                return .focusSelectedWindow
            }
            return action
        }
        set {
            guard newValue != switcherReleaseAction else { return }
            defaults.set(newValue.rawValue, forKey: Keys.switcherReleaseAction)
            NotificationCenter.default.post(name: .switcherReleaseActionDidChange, object: newValue)
        }
    }

    var switcherPreviewSelectedWindow: Bool {
        get {
            if defaults.object(forKey: Keys.switcherPreviewSelectedWindow) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.switcherPreviewSelectedWindow)
        }
        set {
            guard newValue != switcherPreviewSelectedWindow else { return }
            defaults.set(newValue, forKey: Keys.switcherPreviewSelectedWindow)
            NotificationCenter.default.post(
                name: .switcherPreviewSelectedWindowDidChange,
                object: newValue
            )
        }
    }

    var switcherApplicationScope: SwitcherApplicationScope {
        get {
            guard
                let raw = defaults.string(forKey: Keys.switcherApplicationScope),
                let scope = SwitcherApplicationScope(rawValue: raw)
            else {
                return .allApps
            }
            return scope
        }
        set {
            guard newValue != switcherApplicationScope else { return }
            defaults.set(newValue.rawValue, forKey: Keys.switcherApplicationScope)
            NotificationCenter.default.post(name: .switcherApplicationScopeDidChange, object: newValue)
        }
    }

    var switcherScreenScope: SwitcherScreenScope {
        get {
            guard
                let raw = defaults.string(forKey: Keys.switcherScreenScope),
                let scope = SwitcherScreenScope(rawValue: raw)
            else {
                return .currentScreenOnly
            }
            return scope
        }
        set {
            guard newValue != switcherScreenScope else { return }
            defaults.set(newValue.rawValue, forKey: Keys.switcherScreenScope)
            NotificationCenter.default.post(name: .switcherScreenScopeDidChange, object: newValue)
        }
    }

    var switcherMinimizedWindowsVisibility: SwitcherMinimizedWindowsVisibility {
        get {
            guard
                let raw = defaults.string(forKey: Keys.switcherMinimizedWindowsVisibility),
                let visibility = SwitcherMinimizedWindowsVisibility(rawValue: raw)
            else {
                return .show
            }
            return visibility
        }
        set {
            guard newValue != switcherMinimizedWindowsVisibility else { return }
            defaults.set(newValue.rawValue, forKey: Keys.switcherMinimizedWindowsVisibility)
            NotificationCenter.default.post(
                name: .switcherMinimizedWindowsVisibilityDidChange,
                object: newValue
            )
        }
    }

    var switcherHiddenWindowsVisibility: SwitcherHiddenWindowsVisibility {
        get {
            guard
                let raw = defaults.string(forKey: Keys.switcherHiddenWindowsVisibility),
                let visibility = SwitcherHiddenWindowsVisibility(rawValue: raw)
            else {
                return .show
            }
            return visibility
        }
        set {
            guard newValue != switcherHiddenWindowsVisibility else { return }
            defaults.set(newValue.rawValue, forKey: Keys.switcherHiddenWindowsVisibility)
            NotificationCenter.default.post(
                name: .switcherHiddenWindowsVisibilityDidChange,
                object: newValue
            )
        }
    }

    var switcherFullscreenWindowsVisibility: SwitcherFullscreenWindowsVisibility {
        get {
            guard
                let raw = defaults.string(forKey: Keys.switcherFullscreenWindowsVisibility),
                let visibility = SwitcherFullscreenWindowsVisibility(rawValue: raw)
            else {
                return .show
            }
            return visibility
        }
        set {
            guard newValue != switcherFullscreenWindowsVisibility else { return }
            defaults.set(newValue.rawValue, forKey: Keys.switcherFullscreenWindowsVisibility)
            NotificationCenter.default.post(
                name: .switcherFullscreenWindowsVisibilityDidChange,
                object: newValue
            )
        }
    }

    var switcherOrderPreference: SwitcherOrderPreference {
        get {
            guard
                let raw = defaults.string(forKey: Keys.switcherOrderPreference),
                let preference = SwitcherOrderPreference(rawValue: raw)
            else {
                return .recentlyFocusedFirst
            }
            return preference
        }
        set {
            guard newValue != switcherOrderPreference else { return }
            defaults.set(newValue.rawValue, forKey: Keys.switcherOrderPreference)
            NotificationCenter.default.post(
                name: .switcherOrderPreferenceDidChange,
                object: newValue
            )
        }
    }

    var startAtLoginEnabled: Bool {
        get {
            defaults.bool(forKey: Keys.startAtLoginEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.startAtLoginEnabled)
        }
    }

    var menubarIconStyle: MenubarIconStyle {
        get {
            guard
                let raw = defaults.string(forKey: Keys.menubarIconStyle),
                let style = MenubarIconStyle(rawValue: raw)
            else {
                return .default
            }
            return style
        }
        set {
            guard newValue != menubarIconStyle else { return }
            defaults.set(newValue.rawValue, forKey: Keys.menubarIconStyle)
            NotificationCenter.default.post(name: .menubarIconStyleDidChange, object: newValue)
        }
    }

    var menubarIconVisible: Bool {
        get {
            if defaults.object(forKey: Keys.menubarIconVisible) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.menubarIconVisible)
        }
        set {
            guard newValue != menubarIconVisible else { return }
            defaults.set(newValue, forKey: Keys.menubarIconVisible)
            NotificationCenter.default.post(name: .menubarIconVisibilityDidChange, object: newValue)
        }
    }

    var captureWindowsInBackground: Bool {
        get {
            if defaults.object(forKey: Keys.captureWindowsInBackground) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.captureWindowsInBackground)
        }
        set {
            defaults.set(newValue, forKey: Keys.captureWindowsInBackground)
        }
    }

    var appLanguage: AppLanguage {
        get {
            guard
                let raw = defaults.string(forKey: Keys.appLanguage),
                let language = AppLanguage(rawValue: raw)
            else {
                return .system
            }
            return language
        }
        set {
            guard newValue != appLanguage else { return }
            defaults.set(newValue.rawValue, forKey: Keys.appLanguage)
            NotificationCenter.default.post(name: .appLanguageDidChange, object: newValue)
        }
    }

    var updateCheckPolicy: UpdateCheckPolicy {
        get {
            guard
                let raw = defaults.string(forKey: Keys.updateCheckPolicy),
                let policy = UpdateCheckPolicy(rawValue: raw)
            else {
                return .periodically
            }
            return policy
        }
        set {
            guard newValue != updateCheckPolicy else { return }
            defaults.set(newValue.rawValue, forKey: Keys.updateCheckPolicy)
            NotificationCenter.default.post(name: .updateCheckPolicyDidChange, object: newValue)
        }
    }

    var crashReportsPolicy: CrashReportsPolicy {
        get {
            guard
                let raw = defaults.string(forKey: Keys.crashReportsPolicy),
                let policy = CrashReportsPolicy(rawValue: raw)
            else {
                return .ask
            }
            return policy
        }
        set {
            guard newValue != crashReportsPolicy else { return }
            defaults.set(newValue.rawValue, forKey: Keys.crashReportsPolicy)
            NotificationCenter.default.post(name: .crashReportsPolicyDidChange, object: newValue)
        }
    }

    var suppressMoveToApplicationsPrompt: Bool {
        get {
            defaults.bool(forKey: Keys.suppressMoveToApplicationsPrompt)
        }
        set {
            defaults.set(newValue, forKey: Keys.suppressMoveToApplicationsPrompt)
        }
    }

    var licenseKey: String {
        get {
            defaults.string(forKey: Keys.licenseKey) ?? ""
        }
        set {
            defaults.set(newValue, forKey: Keys.licenseKey)
        }
    }

    var licenseStatus: LicenseStatus {
        get {
            guard
                let raw = defaults.string(forKey: Keys.licenseStatus),
                let status = LicenseStatus(rawValue: raw)
            else {
                return .inactive
            }
            return status
        }
        set {
            guard newValue != licenseStatus else { return }
            defaults.set(newValue.rawValue, forKey: Keys.licenseStatus)
            NotificationCenter.default.post(name: .licenseStatusDidChange, object: newValue)
        }
    }

    var licenseActivatedAt: Date? {
        get {
            defaults.object(forKey: Keys.licenseActivatedAt) as? Date
        }
        set {
            defaults.set(newValue, forKey: Keys.licenseActivatedAt)
        }
    }

    var trialStartedAt: Date? {
        get {
            defaults.object(forKey: Keys.trialStartedAt) as? Date
        }
        set {
            defaults.set(newValue, forKey: Keys.trialStartedAt)
        }
    }

    func resetAll() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        defaults.removePersistentDomain(forName: bundleID)
        defaults.synchronize()
    }
}

final class LicenseManager {
    static let shared = LicenseManager()

    private init() {}
    private let productName = "Saltabo"
    private let licenseDeviceIdKey = "Saltabo.licenseDeviceId"

    private var apiBaseURL: String {
        let envValue = ProcessInfo.processInfo.environment["SALTABO_API_BASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let envValue, !envValue.isEmpty {
            return envValue
        }
        return "http://localhost:4000/api/v1"
    }

    enum ActivationError: LocalizedError {
        case invalidFormat
        case invalidURL
        case encodeFailed
        /// Network unreachable, DNS failure, ATS, timeout, etc. (underlying system message).
        case networkFailure(details: String?)
        case serverRejected(message: String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "Please enter a key in the format STB-XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX."
            case .invalidURL:
                return "License server URL is invalid."
            case .encodeFailed:
                return "Could not prepare the activation request."
            case .networkFailure(let details):
                let base = "Cannot reach the license server."
                if let details, !details.isEmpty {
                    return "\(base)\n\n\(details)"
                }
                return "\(base) Check that the server is running and set SALTABO_API_BASE_URL if needed."
            case .serverRejected(let message):
                return message
            }
        }
    }

    var status: LicenseStatus {
        AppSettings.shared.licenseStatus
    }

    var maskedLicenseKey: String {
        let key = AppSettings.shared.licenseKey
        guard key.count > 8 else { return key }
        let start = key.prefix(4)
        let end = key.suffix(4)
        return "\(start)-****-****-\(end)"
    }

    func activate(with rawKey: String, completion: @escaping (Result<Void, ActivationError>) -> Void) {
        let normalized = normalize(rawKey)
        guard isValidFormat(normalized) else {
            completion(.failure(.invalidFormat))
            return
        }
        guard let url = URL(string: "\(apiBaseURL)/licenses/activate") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        let payload: [String: Any] = [
            "product": productName,
            "licenseKey": normalized,
            "device": licenseDevicePayload(),
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(.failure(.encodeFailed))
            return
        }
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { _, response, error in
            // Always commit settings + completion on the main thread (UserDefaults, notifications, UI).
            DispatchQueue.main.async {
                if let error {
                    completion(
                        .failure(
                            .networkFailure(
                                details: (error as NSError).localizedDescription
                            )
                        )
                    )
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard (200...299).contains(statusCode) else {
                    completion(
                        .failure(
                            .serverRejected(
                                message: "License activation failed (HTTP \(statusCode))."
                            )
                        )
                    )
                    return
                }

                AppSettings.shared.licenseKey = normalized
                AppSettings.shared.licenseStatus = .active
                AppSettings.shared.licenseActivatedAt = Date()
                completion(.success(()))
            }
        }.resume()
    }

    func deactivate() {
        AppSettings.shared.licenseKey = ""
        AppSettings.shared.licenseStatus = .inactive
        AppSettings.shared.licenseActivatedAt = nil
    }

    private func normalize(_ key: String) -> String {
        let cleaned = key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return cleaned.components(separatedBy: .whitespacesAndNewlines).joined()
    }

    private func isValidFormat(_ key: String) -> Bool {
        let pattern = "^STB-[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}$"
        return key.range(of: pattern, options: .regularExpression) != nil
    }

    private func licenseDevicePayload() -> [String: String] {
        [
            "device_id": licenseDeviceId(),
            "device_name": Host.current().localizedName ?? ProcessInfo.processInfo.hostName,
            "platform": "macos",
            "arch": architectureName,
        ]
    }

    private func licenseDeviceId() -> String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: licenseDeviceIdKey), !existing.isEmpty {
            return existing
        }

        let generated = UUID().uuidString
        defaults.set(generated, forKey: licenseDeviceIdKey)
        return generated
    }

    private var architectureName: String {
        #if arch(arm64)
            return "arm64"
        #elseif arch(x86_64)
            return "x86_64"
        #else
            return "unknown"
        #endif
    }
}

enum AppAccessState {
    case licensed
    case trial(daysRemaining: Int)
    case blocked
}

final class AppAccessManager {
    static let shared = AppAccessManager()

    private let trialDays = 14
    private let calendar = Calendar.current

    private init() {}

    func bootstrapTrialIfNeeded(now: Date = Date()) {
        if AppSettings.shared.trialStartedAt == nil {
            AppSettings.shared.trialStartedAt = now
        }
    }

    func currentState(now: Date = Date()) -> AppAccessState {
        if LicenseManager.shared.status == .active {
            return .licensed
        }

        let startDate = AppSettings.shared.trialStartedAt ?? now
        if AppSettings.shared.trialStartedAt == nil {
            AppSettings.shared.trialStartedAt = startDate
        }

        let elapsedDays = calendar.dateComponents([.day], from: startDate, to: now).day ?? 0
        let remaining = trialDays - elapsedDays
        if remaining > 0 {
            return .trial(daysRemaining: remaining)
        }
        return .blocked
    }

    var isBlocked: Bool {
        if case .blocked = currentState() {
            return true
        }
        return false
    }
}
