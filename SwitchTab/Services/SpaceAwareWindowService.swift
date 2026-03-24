import AppKit
import CoreGraphics

final class SpaceAwareWindowService {
    static let shared = SpaceAwareWindowService()

    private init() {}

    func currentSpaceApplications(on screen: NSScreen?) -> [SwitcherApp] {
        let visibleWindows = fetchWindows(options: [.optionOnScreenOnly, .excludeDesktopElements])
        let filteredWindows = filter(windows: visibleWindows, to: screen)
        return groupApplications(from: filteredWindows)
    }

    func currentSpaceApplications() -> [SwitcherApp] {
        let visibleWindows = fetchWindows(options: [.optionOnScreenOnly, .excludeDesktopElements])
        return groupApplications(from: visibleWindows)
    }

    func windowsForDockPreview(for app: NSRunningApplication) -> [WindowDescriptor] {
        let windows = fetchWindows(options: [.optionAll]).filter { $0.pid == app.processIdentifier }
        if windows.isEmpty {
            return currentSpaceWindows(for: app.processIdentifier)
        }
        return windows
    }

    func currentSpaceWindows(for pid: pid_t) -> [WindowDescriptor] {
        fetchWindows(options: [.optionOnScreenOnly, .excludeDesktopElements]).filter { $0.pid == pid }
    }

    func activate(app: SwitcherApp) {
        focus(window: app.primaryWindow)
    }

    func focus(window: WindowDescriptor) {
        if let app = NSRunningApplication(processIdentifier: window.pid) {
            app.activate(options: [.activateAllWindows])
        }

        if !AccessibilityService.shared.raiseWindow(matching: window),
           let app = NSRunningApplication(processIdentifier: window.pid) {
            app.activate()
        }
    }

    private func groupApplications(from windows: [WindowDescriptor]) -> [SwitcherApp] {
        var order: [pid_t] = []
        var grouped: [pid_t: [WindowDescriptor]] = [:]

        for window in windows {
            if grouped[window.pid] == nil {
                order.append(window.pid)
            }
            grouped[window.pid, default: []].append(window)
        }

        return order.compactMap { pid in
            guard let appWindows = grouped[pid], let first = appWindows.first else {
                return nil
            }
            return SwitcherApp(
                pid: pid,
                bundleIdentifier: first.bundleIdentifier,
                appName: first.appName,
                windows: appWindows.sorted { $0.orderIndex < $1.orderIndex }
            )
        }
    }

    private func filter(windows: [WindowDescriptor], to screen: NSScreen?) -> [WindowDescriptor] {
        guard let screen else { return windows }
        return windows.filter { screen.frame.contains(CGPoint(x: $0.bounds.midX, y: $0.bounds.midY)) }
    }

    private func fetchWindows(options: CGWindowListOption) -> [WindowDescriptor] {
        guard let rawList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier

        return rawList.enumerated().compactMap { index, rawWindow in
            let layer = rawWindow[kCGWindowLayer as String] as? Int ?? 1
            let alpha = rawWindow[kCGWindowAlpha as String] as? Double ?? 0
            let ownerName = rawWindow[kCGWindowOwnerName as String] as? String ?? ""
            let sharingState = rawWindow[kCGWindowSharingState as String] as? Int ?? 0

            guard layer == 0, alpha > 0.05, sharingState != 0 else { return nil }
            guard let id = rawWindow[kCGWindowNumber as String] as? UInt32,
                  let pid = rawWindow[kCGWindowOwnerPID as String] as? pid_t,
                  pid != ownPID,
                  ownerName != "Dock",
                  ownerName != "Window Server" else {
                return nil
            }

            let boundsData = rawWindow[kCGWindowBounds as String] as? [String: Any] ?? [:]
            let bounds = CGRect(dictionaryRepresentation: boundsData as CFDictionary) ?? .zero
            guard bounds.width >= 96, bounds.height >= 64 else { return nil }

            let app = NSRunningApplication(processIdentifier: pid)
            guard app?.activationPolicy == .regular else { return nil }

            return WindowDescriptor(
                id: id,
                pid: pid,
                bundleIdentifier: app?.bundleIdentifier,
                appName: app?.localizedName ?? ownerName,
                title: rawWindow[kCGWindowName as String] as? String ?? "",
                bounds: bounds,
                windowLayer: layer,
                orderIndex: index
            )
        }
    }
}
