import AppKit
import ApplicationServices

final class AccessibilityService {
    static let shared = AccessibilityService()

    struct PermissionSnapshot {
        let accessibilityGranted: Bool
        let inputMonitoringGranted: Bool

        var allGranted: Bool {
            accessibilityGranted && inputMonitoringGranted
        }
    }

    private init() {}

    @discardableResult
    func requestRequiredPermissions() -> PermissionSnapshot {
        let accessibilityOptions: [String: Bool] = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
        ]

        let accessibilityGranted = AXIsProcessTrustedWithOptions(accessibilityOptions as CFDictionary)
        let inputMonitoringGranted = CGPreflightListenEventAccess() || CGRequestListenEventAccess()

        return PermissionSnapshot(
            accessibilityGranted: accessibilityGranted,
            inputMonitoringGranted: inputMonitoringGranted
        )
    }

    func presentPermissionAlertIfNeeded() {
        let snapshot = requestRequiredPermissions()
        guard !snapshot.allGranted else { return }

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Additional Permissions Required"
            alert.informativeText = """
            SwitchTab needs both Accessibility and Input Monitoring to override Command-Tab and inspect Dock items.

            Enable this app in:
            - System Settings > Privacy & Security > Accessibility
            - System Settings > Privacy & Security > Input Monitoring

            Relaunch the app after granting permissions.
            """
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    func element(at point: CGPoint) -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var result: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &result)
        guard error == .success else { return nil }
        return result
    }

    func stringValue(for attribute: String, on element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    func frame(for element: AXUIElement) -> CGRect? {
        guard let position = pointValue(for: kAXPositionAttribute, on: element),
              let size = sizeValue(for: kAXSizeAttribute, on: element) else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    func pointValue(for attribute: String, on element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else {
            return nil
        }

        let axValue = value as! AXValue
        var point = CGPoint.zero
        guard AXValueGetType(axValue) == .cgPoint,
              AXValueGetValue(axValue, .cgPoint, &point) else {
            return nil
        }
        return point
    }

    func sizeValue(for attribute: String, on element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else {
            return nil
        }

        let axValue = value as! AXValue
        var size = CGSize.zero
        guard AXValueGetType(axValue) == .cgSize,
              AXValueGetValue(axValue, .cgSize, &size) else {
            return nil
        }
        return size
    }

    func pid(for element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return pid
    }

    func windows(for pid: pid_t) -> [AXUIElement] {
        let appElement = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else {
            return []
        }
        return windows
    }

    func raiseWindow(matching descriptor: WindowDescriptor) -> Bool {
        for window in windows(for: descriptor.pid) {
            let title = stringValue(for: kAXTitleAttribute, on: window) ?? ""
            let frame = frame(for: window) ?? .zero

            let sameTitle = descriptor.title.isEmpty || title == descriptor.title
            let sameFrame = abs(frame.origin.x - descriptor.bounds.origin.x) < 2 &&
                abs(frame.origin.y - descriptor.bounds.origin.y) < 2

            guard sameTitle || sameFrame else { continue }

            _ = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            _ = AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            _ = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            return AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success
        }

        return false
    }

    func browserTabTitles(for pid: pid_t) -> [String] {
        windows(for: pid).compactMap { window in
            stringValue(for: kAXTitleAttribute, on: window)
        }
    }

    func hoveredDockApplication(at point: CGPoint) -> NSRunningApplication? {
        guard let element = element(at: point),
              let dockPID = pid(for: element),
              let dockApp = NSRunningApplication(processIdentifier: dockPID),
              dockApp.bundleIdentifier == "com.apple.dock" else {
            return nil
        }

        let candidates = candidateStrings(startingAt: element, depth: 8)
        guard !candidates.isEmpty else { return nil }

        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }

        for candidate in candidates {
            if let match = runningApps.first(where: {
                $0.localizedName?.localizedCaseInsensitiveCompare(candidate) == .orderedSame ||
                $0.bundleIdentifier?.localizedCaseInsensitiveContains(candidate) == true
            }) {
                return match
            }
        }

        return nil
    }

    private func candidateStrings(startingAt element: AXUIElement, depth: Int) -> [String] {
        var output: [String] = []
        var current: AXUIElement? = element
        var remainingDepth = depth

        while remainingDepth > 0, let currentElement = current {
            [kAXTitleAttribute, kAXDescriptionAttribute, kAXIdentifierAttribute].forEach { attribute in
                if let value = stringValue(for: attribute, on: currentElement), !value.isEmpty {
                    output.append(value)
                }
            }

            var parentValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(currentElement, kAXParentAttribute as CFString, &parentValue) == .success,
               let parent = parentValue {
                current = (parent as! AXUIElement)
            } else {
                current = nil
            }
            remainingDepth -= 1
        }

        return Array(NSOrderedSet(array: output)) as? [String] ?? output
    }
}
