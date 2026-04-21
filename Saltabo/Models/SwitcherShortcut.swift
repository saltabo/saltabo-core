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
        static let suppressMoveToApplicationsPrompt = "Saltabo.suppressMoveToApplicationsPrompt"
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

    var suppressMoveToApplicationsPrompt: Bool {
        get {
            defaults.bool(forKey: Keys.suppressMoveToApplicationsPrompt)
        }
        set {
            defaults.set(newValue, forKey: Keys.suppressMoveToApplicationsPrompt)
        }
    }
}
