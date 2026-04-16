import AppKit
import ApplicationServices
import CoreGraphics

final class AccessibilityService {
    static let shared = AccessibilityService()

    struct AXWindowSnapshot {
        let title: String
        let frame: CGRect
        let isMain: Bool
    }

    struct DockHoverMatch {
        let app: NSRunningApplication
        let frame: CGRect
    }

    struct PermissionSnapshot {
        let accessibilityGranted: Bool
        let screenRecordingGranted: Bool

        func corePermissionsGranted(for _: SwitcherShortcut) -> Bool {
            accessibilityGranted
        }

        func allGranted(for shortcut: SwitcherShortcut) -> Bool {
            corePermissionsGranted(for: shortcut) && screenRecordingGranted
        }
    }

    private init() {}

    func currentPermissionSnapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            accessibilityGranted: AXIsProcessTrusted(),
            screenRecordingGranted: CGPreflightScreenCaptureAccess()
        )
    }

    @discardableResult
    func requestRequiredPermissions() -> PermissionSnapshot {
        currentPermissionSnapshot()
    }

    @discardableResult
    func requestAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func openAccessibilitySettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openScreenRecordingSettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    func presentPermissionAlertIfNeeded() {
        _ = requestRequiredPermissions()
    }

    func element(at point: CGPoint) -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var result: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(
            systemWide, Float(point.x), Float(point.y), &result)
        guard error == .success else { return nil }
        return result
    }

    func stringValue(for attribute: String, on element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else {
            return nil
        }
        return value as? String
    }

    func elementsValue(for attribute: String, on element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
            let elements = value as? [AXUIElement]
        else {
            return []
        }
        return elements
    }

    func frame(for element: AXUIElement) -> CGRect? {
        guard let position = pointValue(for: kAXPositionAttribute, on: element),
            let size = sizeValue(for: kAXSizeAttribute, on: element)
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    func pointValue(for attribute: String, on element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
            let value
        else {
            return nil
        }

        let axValue = value as! AXValue
        var point = CGPoint.zero
        guard AXValueGetType(axValue) == .cgPoint,
            AXValueGetValue(axValue, .cgPoint, &point)
        else {
            return nil
        }
        return point
    }

    func sizeValue(for attribute: String, on element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
            let value
        else {
            return nil
        }

        let axValue = value as! AXValue
        var size = CGSize.zero
        guard AXValueGetType(axValue) == .cgSize,
            AXValueGetValue(axValue, .cgSize, &size)
        else {
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
        guard
            AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
                == .success,
            let windows = value as? [AXUIElement]
        else {
            return []
        }
        return windows
    }

    func windowSnapshots(for pid: pid_t) -> [AXWindowSnapshot] {
        windows(for: pid).compactMap { window in
            guard let frame = frame(for: window) else { return nil }
            let title = stringValue(for: kAXTitleAttribute, on: window) ?? ""
            let isMain = booleanValue(for: kAXMainAttribute, on: window) ?? false
            return AXWindowSnapshot(title: title, frame: frame, isMain: isMain)
        }
    }

    func raiseWindow(matching descriptor: WindowDescriptor) -> Bool {
        let candidates = windows(for: descriptor.pid).compactMap { window -> (AXUIElement, CGFloat)? in
            let title = stringValue(for: kAXTitleAttribute, on: window) ?? ""
            let frame = frame(for: window) ?? .zero
            let score = windowMatchScore(title: title, frame: frame, descriptor: descriptor)
            return score > 0 ? (window, score) : nil
        }

        guard let bestWindow = candidates.max(by: { $0.1 < $1.1 })?.0 else {
            return false
        }

        _ = AXUIElementSetAttributeValue(bestWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementSetAttributeValue(
            bestWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementSetAttributeValue(
            bestWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        return AXUIElementPerformAction(bestWindow, kAXRaiseAction as CFString) == .success
    }

    private func windowMatchScore(title: String, frame: CGRect, descriptor: WindowDescriptor) -> CGFloat {
        let normalizedDescriptorTitle = descriptor.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        let sameOrigin =
            abs(frame.origin.x - descriptor.bounds.origin.x) < 2
            && abs(frame.origin.y - descriptor.bounds.origin.y) < 2
        let sameSize =
            abs(frame.width - descriptor.bounds.width) < 2
            && abs(frame.height - descriptor.bounds.height) < 2

        var score: CGFloat = 0

        if !normalizedDescriptorTitle.isEmpty {
            if normalizedTitle == normalizedDescriptorTitle {
                score += 10
            } else if normalizedTitle.localizedCaseInsensitiveContains(normalizedDescriptorTitle)
                || normalizedDescriptorTitle.localizedCaseInsensitiveContains(normalizedTitle)
            {
                score += 5
            }
        }

        if sameOrigin {
            score += 3
        }

        if sameSize {
            score += 2
        }

        return score
    }

    func browserTabTitles(for pid: pid_t) -> [String] {
        windows(for: pid).compactMap { window in
            stringValue(for: kAXTitleAttribute, on: window)
        }
    }

    func booleanValue(for attribute: String, on element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
            let value
        else {
            return nil
        }

        if CFGetTypeID(value) == CFBooleanGetTypeID() {
            return CFBooleanGetValue((value as! CFBoolean))
        }

        return nil
    }

    func hoveredDockApplication(at point: CGPoint) -> NSRunningApplication? {
        hoveredDockMatch(at: point)?.app
    }

    func hoveredDockMatch(at point: CGPoint) -> DockHoverMatch? {
        guard let sourceScreen = screen(containingAppKitPoint: point) else {
            return nil
        }

        let axPoint = appKitPointToAccessibility(point, in: sourceScreen)

        guard isPointInsideDock(axPoint) else {
            return nil
        }

        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }

        guard let hitElement = element(at: axPoint) else {
            return nil
        }

        let dockApp = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.dock"
        ).first
        guard let dockApp else { return nil }

        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)
        let dockItemHits: [DockItemHit] = dockItems(in: dockElement).compactMap {
            dockItem -> DockItemHit? in
            guard let title = stringValue(for: kAXTitleAttribute, on: dockItem),
                !title.isEmpty,
                let frame = frame(for: dockItem)
            else {
                return nil
            }
            return DockItemHit(title: title, frame: frame)
        }

        let containingHits = dockItemHits.filter { $0.frame.contains(axPoint) }
        guard !containingHits.isEmpty else {
            return nil
        }

        let titleCandidates = candidateStrings(startingAt: hitElement, depth: 8)

        guard
            let selectedHit = selectDockItemHit(
                from: containingHits,
                point: axPoint,
                titleCandidates: titleCandidates
            )
        else {
            return nil
        }

        guard let app = resolveRunningApp(forDockTitle: selectedHit.title, runningApps: runningApps)
        else {
            return nil
        }

        let appKitFrame = accessibilityFrameToAppKit(selectedHit.frame, in: sourceScreen)
        return DockHoverMatch(app: app, frame: appKitFrame)
    }

    func isPointInsideDock(_ point: CGPoint) -> Bool {
        guard
            let windows = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else {
            return false
        }

        return windows.contains { rawWindow in
            let ownerName = rawWindow[kCGWindowOwnerName as String] as? String
            guard ownerName == "Dock" else { return false }
            let boundsData = rawWindow[kCGWindowBounds as String] as? [String: Any] ?? [:]
            guard let bounds = CGRect(dictionaryRepresentation: boundsData as CFDictionary) else {
                return false
            }
            return bounds.contains(point)
        }
    }

    private func candidateStrings(startingAt element: AXUIElement, depth: Int) -> [String] {
        var output: [String] = []
        var current: AXUIElement? = element
        var remainingDepth = depth

        while remainingDepth > 0, let currentElement = current {
            [kAXTitleAttribute, kAXDescriptionAttribute, kAXIdentifierAttribute].forEach {
                attribute in
                if let value = stringValue(for: attribute, on: currentElement), !value.isEmpty {
                    output.append(value)
                }
            }

            var parentValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                currentElement, kAXParentAttribute as CFString, &parentValue) == .success,
                let parent = parentValue
            {
                current = (parent as! AXUIElement)
            } else {
                current = nil
            }
            remainingDepth -= 1
        }

        return Array(NSOrderedSet(array: output)) as? [String] ?? output
    }

    private func dockDescendants(startingAt root: AXUIElement, maxDepth: Int) -> [AXUIElement] {
        guard maxDepth >= 0 else { return [] }

        var results: [AXUIElement] = [root]
        guard maxDepth > 0 else { return results }

        for child in elementsValue(for: kAXChildrenAttribute, on: root) {
            results.append(contentsOf: dockDescendants(startingAt: child, maxDepth: maxDepth - 1))
        }

        return results
    }

    private func dockItems(in dockElement: AXUIElement) -> [AXUIElement] {
        dockDescendants(startingAt: dockElement, maxDepth: 3).filter {
            stringValue(for: kAXRoleAttribute, on: $0) == kAXDockItemRole as String
                && stringValue(for: kAXSubroleAttribute, on: $0) == kAXApplicationDockItemSubrole
                    as String
        }
    }

    private func selectDockItemHit(
        from hits: [DockItemHit], point: CGPoint, titleCandidates: [String]
    ) -> DockItemHit? {
        let candidateSet = Set(titleCandidates.map { normalize($0) })
        let candidateHits = hits.filter { candidateSet.contains(normalize($0.title)) }
        if !candidateHits.isEmpty {
            return candidateHits.min(by: {
                distance(from: point, to: CGPoint(x: $0.frame.midX, y: $0.frame.midY))
                    < distance(from: point, to: CGPoint(x: $1.frame.midX, y: $1.frame.midY))
            })
        }

        return hits.min(by: {
            distance(from: point, to: CGPoint(x: $0.frame.midX, y: $0.frame.midY))
                < distance(from: point, to: CGPoint(x: $1.frame.midX, y: $1.frame.midY))
        })
    }

    private func resolveRunningApp(
        forDockTitle dockTitle: String, runningApps: [NSRunningApplication]
    ) -> NSRunningApplication? {
        let target = normalize(dockTitle)

        if let exact = runningApps.first(where: { normalize($0.localizedName ?? "") == target }) {
            return exact
        }

        return runningApps.first {
            let name = normalize($0.localizedName ?? "")
            return !name.isEmpty && (name.contains(target) || target.contains(name))
        }
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func screen(containingAppKitPoint point: CGPoint) -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
    }

    private func appKitPointToAccessibility(_ point: CGPoint, in screen: NSScreen) -> CGPoint {
        let localY = point.y - screen.frame.minY
        let flippedLocalY = screen.frame.height - localY
        return CGPoint(x: point.x, y: screen.frame.minY + flippedLocalY)
    }

    private func accessibilityFrameToAppKit(_ frame: CGRect, in screen: NSScreen) -> CGRect {
        let localTopY = frame.minY - screen.frame.minY
        let appKitMinY = screen.frame.minY + (screen.frame.height - localTopY - frame.height)
        return CGRect(x: frame.minX, y: appKitMinY, width: frame.width, height: frame.height)
    }

    private struct DockItemHit {
        let title: String
        let frame: CGRect
    }

    private func openSystemSettings(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
