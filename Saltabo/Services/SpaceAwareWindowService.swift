import AppKit
import CoreGraphics

final class SpaceAwareWindowService {
    static let shared = SpaceAwareWindowService()

    private let accessibilityService = AccessibilityService.shared

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

    func switcherApplications(on screen: NSScreen?) -> [SwitcherApp] {
        let screenScoped = currentSpaceApplications(on: screen)
        if !screenScoped.isEmpty {
            return screenScoped
        }

        let currentSpace = currentSpaceApplications()
        if !currentSpace.isEmpty {
            return currentSpace
        }

        let allWindows = fetchWindows(options: [.optionAll])
        return groupApplications(from: allWindows)
    }

    func windowsForDockPreview(for app: NSRunningApplication) -> [WindowDescriptor] {
        let allWindows = fetchWindows(options: [.optionAll])
            .filter { $0.pid == app.processIdentifier }
            .filter { isEligibleForDockPreview($0, app: app) }

        if allWindows.isEmpty {
            let fallbackWindows = currentSpaceWindows(for: app.processIdentifier)
                .filter { isEligibleForDockPreview($0, app: app) }
            return preferredPreviewWindows(from: fallbackWindows)
        }

        if isGoogleChrome(app) {
            let currentSpaceWindows = fetchWindows(options: [.optionOnScreenOnly, .excludeDesktopElements])
                .filter { $0.pid == app.processIdentifier }
                .filter { isEligibleForDockPreview($0, app: app) }

            let sourceWindows = preferredPreviewWindows(
                from: currentSpaceWindows.isEmpty ? allWindows : currentSpaceWindows
            )
            return chromePreviewWindows(from: sourceWindows, pid: app.processIdentifier)
        }

        return preferredPreviewWindows(from: allWindows)
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

            // Do not gate switcher candidates on sharingState: after app identity
            // changes (bundle-id / TCC reset), windows can report unshareable and
            // still be valid targets for activation.
            guard layer == 0, alpha > 0.05 else { return nil }
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

    private func isGoogleChrome(_ app: NSRunningApplication) -> Bool {
        let bundleID = app.bundleIdentifier ?? ""
        return bundleID == "com.google.Chrome" || bundleID == "com.google.Chrome.canary"
    }

    private func dedupeChromeWindowsByProfile(_ windows: [WindowDescriptor]) -> [WindowDescriptor] {
        var grouped: [String: [WindowDescriptor]] = [:]
        var groupOrder: [String] = []

        for window in windows.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            let key = chromeProfileKey(for: window)
            if grouped[key] == nil {
                groupOrder.append(key)
            }
            grouped[key, default: []].append(window)
        }

        let hasResolvedProfileGroup = groupOrder.contains { $0 != "__chrome_default_profile__" }

        return groupOrder.compactMap { key in
            if hasResolvedProfileGroup, key == "__chrome_default_profile__" {
                return nil
            }

            guard let candidates = grouped[key], !candidates.isEmpty else { return nil }

            let titledCandidates = candidates.filter(hasChromeWindowTitle)
            let effectiveCandidates = titledCandidates.isEmpty ? candidates : titledCandidates
            let best = effectiveCandidates.sorted(by: chromeWindowPreference).first
            return best
        }
    }

    private func chromePreviewWindows(from windows: [WindowDescriptor], pid: pid_t) -> [WindowDescriptor] {
        let snapshots = accessibilityService.windowSnapshots(for: pid)
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard !snapshots.isEmpty else {
            return dedupeChromeWindowsByProfile(windows)
        }

        let sortedSnapshots = snapshots.sorted { lhs, rhs in
            if lhs.isMain != rhs.isMain {
                return lhs.isMain
            }
            return lhs.title < rhs.title
        }

        var remainingWindows = windows.sorted(by: { $0.orderIndex < $1.orderIndex })
        var results: [WindowDescriptor] = []

        for snapshot in sortedSnapshots {
            guard let bestIndex = remainingWindows.indices.max(by: {
                chromeMatchScore(snapshot: snapshot, window: remainingWindows[$0]) <
                    chromeMatchScore(snapshot: snapshot, window: remainingWindows[$1])
            }) else {
                continue
            }

            let bestWindow = remainingWindows.remove(at: bestIndex)
            let score = chromeMatchScore(snapshot: snapshot, window: bestWindow)
            guard score > 0.15 else { continue }

            results.append(
                WindowDescriptor(
                    id: bestWindow.id,
                    pid: bestWindow.pid,
                    bundleIdentifier: bestWindow.bundleIdentifier,
                    appName: bestWindow.appName,
                    title: snapshot.title,
                    bounds: bestWindow.bounds,
                    windowLayer: bestWindow.windowLayer,
                    orderIndex: bestWindow.orderIndex
                )
            )
        }

        if !results.isEmpty {
            return results.sorted(by: chromeWindowPreference)
        }

        return dedupeChromeWindowsByProfile(windows)
    }

    private func chromeWindowPreference(_ lhs: WindowDescriptor, _ rhs: WindowDescriptor) -> Bool {
        let lhsHasTitle = !lhs.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let rhsHasTitle = !rhs.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if lhsHasTitle != rhsHasTitle {
            return lhsHasTitle
        }

        let lhsArea = lhs.bounds.width * lhs.bounds.height
        let rhsArea = rhs.bounds.width * rhs.bounds.height
        if abs(lhsArea - rhsArea) > 1 {
            return lhsArea > rhsArea
        }

        return lhs.orderIndex < rhs.orderIndex
    }

    private func preferredPreviewWindows(from windows: [WindowDescriptor]) -> [WindowDescriptor] {
        let titledWindows = windows.filter(isActionablePreviewWindow)
        if !titledWindows.isEmpty {
            return titledWindows
        }

        let previewableWindows = windows.filter(hasRenderablePreview)
        if !previewableWindows.isEmpty {
            return previewableWindows
        }

        return windows
    }

    private func isActionablePreviewWindow(_ window: WindowDescriptor) -> Bool {
        let trimmedTitle = window.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }

        let normalizedTitle = trimmedTitle.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let normalizedAppName = window.appName.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        return normalizedTitle != normalizedAppName
    }

    private func hasRenderablePreview(_ window: WindowDescriptor) -> Bool {
        ThumbnailCache.shared.image(for: window, targetSize: NSSize(width: 64, height: 40)) != nil
    }

    private func chromeMatchScore(
        snapshot: AccessibilityService.AXWindowSnapshot,
        window: WindowDescriptor
    ) -> CGFloat {
        let overlap = overlapArea(between: snapshot.frame, and: window.bounds)
        let maxArea = max(snapshot.frame.width * snapshot.frame.height, window.bounds.width * window.bounds.height, 1)
        let overlapRatio = overlap / maxArea

        let centerDistance = distance(
            from: CGPoint(x: snapshot.frame.midX, y: snapshot.frame.midY),
            to: CGPoint(x: window.bounds.midX, y: window.bounds.midY)
        )
        let normalizedDistance = min(centerDistance / 400, 1)

        var score = overlapRatio * 3 - normalizedDistance
        if snapshot.isMain {
            score += 0.15
        }

        let normalizedSnapshotTitle = snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedWindowTitle = window.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedSnapshotTitle.isEmpty && normalizedSnapshotTitle == normalizedWindowTitle {
            score += 0.4
        }

        return score
    }

    private func overlapArea(between lhs: CGRect, and rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }

    private func distance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private func chromeProfileKey(for window: WindowDescriptor) -> String {
        let title = window.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return "__chrome_default_profile__"
        }

        let parts = title
            .components(separatedBy: " - ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let chromeIndex = parts.lastIndex(where: { $0.localizedCaseInsensitiveContains("google chrome") }),
           chromeIndex + 1 < parts.count {
            let profileName = parts[(chromeIndex + 1)...].joined(separator: " - ")
            if !profileName.isEmpty {
                return profileName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            }
        }

        return "__chrome_default_profile__"
    }

    private func hasChromeWindowTitle(_ window: WindowDescriptor) -> Bool {
        !window.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isEligibleForDockPreview(_ window: WindowDescriptor, app: NSRunningApplication) -> Bool {
        let title = window.title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Xcode can expose utility windows that are not actionable from Dock previews.
        // Excluding these keeps the preview list focused on real editor/project windows.
        if app.bundleIdentifier == "com.apple.dt.Xcode" {
            let ignoredXcodeTitles: Set<String> = [
                "App Shortcuts Preview",
                "Archives",
                "Organizer",
                "Devices and Simulators"
            ]
            if ignoredXcodeTitles.contains(title) {
                return false
            }
        }

        return true
    }
}
