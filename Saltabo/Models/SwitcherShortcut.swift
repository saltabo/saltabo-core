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
        tabKeyCode == 48 && flags.contains(modifierFlags)
    }

    func matchesModifierRelease(keyCode: Int64, flags: CGEventFlags) -> Bool {
        modifierReleaseKeyCodes.contains(keyCode) && !flags.contains(modifierFlags)
    }
}

extension Notification.Name {
    static let switcherShortcutDidChange = Notification.Name("Saltabo.switcherShortcutDidChange")
    static let switcherDisplayStyleDidChange = Notification.Name("Saltabo.switcherDisplayStyleDidChange")
    static let switcherSizePresetDidChange = Notification.Name("Saltabo.switcherSizePresetDidChange")
    static let switcherThemePresetDidChange = Notification.Name("Saltabo.switcherThemePresetDidChange")
    static let switcherReleaseActionDidChange = Notification.Name("Saltabo.switcherReleaseActionDidChange")
    static let switcherPreviewSelectedWindowDidChange = Notification.Name("Saltabo.switcherPreviewSelectedWindowDidChange")
    static let switcherAvailabilityDidChange = Notification.Name(
        "Saltabo.switcherAvailabilityDidChange")
}

final class AppSettings {
    static let shared = AppSettings()

    private enum Keys {
        static let switcherShortcut = "Saltabo.switcherShortcut"
        static let switcherDisplayStyle = "Saltabo.switcherDisplayStyle"
        static let switcherSizePreset = "Saltabo.switcherSizePreset"
        static let switcherThemePreset = "Saltabo.switcherThemePreset"
        static let switcherReleaseAction = "Saltabo.switcherReleaseAction"
        static let switcherPreviewSelectedWindow = "Saltabo.switcherPreviewSelectedWindow"
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

    var suppressMoveToApplicationsPrompt: Bool {
        get {
            defaults.bool(forKey: Keys.suppressMoveToApplicationsPrompt)
        }
        set {
            defaults.set(newValue, forKey: Keys.suppressMoveToApplicationsPrompt)
        }
    }
}
