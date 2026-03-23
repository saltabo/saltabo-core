import AppKit

final class DockPreviewManager {
    static let shared = DockPreviewManager()

    private let accessibilityService = AccessibilityService.shared
    private let windowService = SpaceAwareWindowService.shared
    private let previewWindow = PreviewPanelWindow()

    private var monitor: Any?
    private var pollingTimer: Timer?
    private var currentBundleIdentifier: String?

    private init() {}

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handle(event: event)
        }

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] _ in
            self?.refreshForCurrentMouseLocation()
        }
    }

    func stop() {
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
            hidePreview()
        }
    }

    private func refreshForCurrentMouseLocation() {
        let location = NSEvent.mouseLocation
        guard let app = accessibilityService.hoveredDockApplication(at: location) else {
            hidePreview()
            return
        }

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
        previewWindow.show(windows: windows, appName: app.localizedName ?? "App", anchorPoint: location) { [weak self] window in
            self?.windowService.focus(window: window)
            self?.hidePreview()
        }
    }

    private var previewWindowIsUseful: Bool {
        currentBundleIdentifier != nil
    }

    private func hidePreview() {
        currentBundleIdentifier = nil
        previewWindow.hide()
    }
}
