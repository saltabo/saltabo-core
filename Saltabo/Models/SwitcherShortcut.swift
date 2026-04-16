import AppKit
import CoreGraphics

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
    static let switcherAvailabilityDidChange = Notification.Name(
        "Saltabo.switcherAvailabilityDidChange")
}

final class AppSettings {
    static let shared = AppSettings()

    private enum Keys {
        static let switcherShortcut = "Saltabo.switcherShortcut"
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

    var suppressMoveToApplicationsPrompt: Bool {
        get {
            defaults.bool(forKey: Keys.suppressMoveToApplicationsPrompt)
        }
        set {
            defaults.set(newValue, forKey: Keys.suppressMoveToApplicationsPrompt)
        }
    }
}
