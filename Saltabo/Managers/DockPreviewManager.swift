import AppKit

final class DockPreviewManager {
    static let shared = DockPreviewManager()

    private enum Timing {
        static let hideGraceInterval: TimeInterval = 0.24
    }

    private let accessibilityService = AccessibilityService.shared
    private let windowService = SpaceAwareWindowService.shared
    private let previewWindow = PreviewPanelWindow()

    private var monitor: Any?
    private var pollingTimer: Timer?
    private var currentBundleIdentifier: String?
    private var pendingHideWorkItem: DispatchWorkItem?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreviewSelectedWindowSettingChanged),
            name: .switcherPreviewSelectedWindowDidChange,
            object: nil
        )
    }

    func start() {
        applyMonitoringStateFromSettings()
    }

    func stop() {
        disableMonitoring()
    }

    @objc private func handlePreviewSelectedWindowSettingChanged() {
        applyMonitoringStateFromSettings()
    }

    private func applyMonitoringStateFromSettings() {
        if AppSettings.shared.switcherPreviewSelectedWindow {
            enableMonitoring()
        } else {
            disableMonitoring()
            hidePreview()
        }
    }

    private func enableMonitoring() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .mouseMoved, .leftMouseDown, .rightMouseDown,
        ]) { [weak self] event in
            self?.handle(event: event)
        }

        guard pollingTimer == nil else { return }
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) {
            [weak self] _ in
            self?.refreshForCurrentMouseLocation()
        }
    }

    private func disableMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func handle(event: NSEvent) {
        switch event.type {
        case .mouseMoved:
            refreshForCurrentMouseLocation()
        default:
            if previewWindow.contains(screenPoint: NSEvent.mouseLocation) {
                return
            }
            hidePreview()
        }
    }

    private func refreshForCurrentMouseLocation() {
        let location = NSEvent.mouseLocation

        guard let hoverMatch = accessibilityService.hoveredDockMatch(at: location) else {
            if previewWindow.contains(screenPoint: location) {
                cancelPendingHide()
                return
            }
            scheduleHidePreview()
            return
        }

        cancelPendingHide()

        let app = hoverMatch.app
        let anchorPoint = CGPoint(x: hoverMatch.frame.midX, y: hoverMatch.frame.midY)

        if currentBundleIdentifier == app.bundleIdentifier, previewWindowIsUseful {
            return
        }

        let windows = windowService.windowsForDockPreview(for: app)
        guard !windows.isEmpty else {
            hidePreview()
            return
        }

        currentBundleIdentifier = app.bundleIdentifier
        ThumbnailCache.shared.warm(windows, targetSize: NSSize(width: 236, height: 132))
        previewWindow.show(
            windows: windows, appName: app.localizedName ?? "App", anchorPoint: anchorPoint
        ) { [weak self] window in
            self?.windowService.focus(window: window)
            self?.hidePreview()
        }
    }

    private var previewWindowIsUseful: Bool {
        currentBundleIdentifier != nil && previewWindow.isVisible
    }

    private func hidePreview() {
        cancelPendingHide()
        currentBundleIdentifier = nil
        previewWindow.hide()
    }

    private func scheduleHidePreview() {
        guard currentBundleIdentifier != nil else { return }
        guard pendingHideWorkItem == nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.pendingHideWorkItem = nil
            self?.hidePreview()
        }
        pendingHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Timing.hideGraceInterval, execute: workItem)
    }

    private func cancelPendingHide() {
        pendingHideWorkItem?.cancel()
        pendingHideWorkItem = nil
    }
}
