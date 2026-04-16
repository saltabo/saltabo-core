import AppKit

private final class DockPreviewPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PreviewPanelWindow {
    private enum Metrics {
        static let itemSize = NSSize(width: 260, height: 190)
        static let itemSpacing: CGFloat = 12
        static let contentPadding: CGFloat = 12
        static let panelInset: CGFloat = 8
    }

    private let panel: NSPanel
    private let rootView = TransparentPanelContentView()
    private let backgroundCardView = NSView()
    private let blurView = NSVisualEffectView()

    init() {
        panel = DockPreviewPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 260),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.alphaValue = 1
        panel.hasShadow = false
        panel.hidesOnDeactivate = false

        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.clear.cgColor

        backgroundCardView.wantsLayer = true
        backgroundCardView.layer?.cornerRadius = 24
        backgroundCardView.layer?.masksToBounds = true
        backgroundCardView.layer?.borderWidth = 1
        backgroundCardView.layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor
        backgroundCardView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.28).cgColor
        backgroundCardView.layer?.shadowOpacity = 1
        backgroundCardView.layer?.shadowRadius = 24
        backgroundCardView.layer?.shadowOffset = NSSize(width: 0, height: -8)

        blurView.material = .hudWindow
        blurView.blendingMode = .withinWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = 24
        blurView.layer?.masksToBounds = true

        rootView.addSubview(backgroundCardView)
        backgroundCardView.addSubview(blurView)
        panel.contentView = rootView
    }

    func show(
        windows: [WindowDescriptor],
        appName: String,
        anchorPoint: CGPoint,
        activate: @escaping (WindowDescriptor) -> Void
    ) {
        let displayedWindows = Array(windows.prefix(6))
        guard !displayedWindows.isEmpty else { return }

        let panelSize = panelSize(for: displayedWindows.count)
        layoutChrome(panelSize: panelSize)
        rootView.layoutSubtreeIfNeeded()
        rebuild(windows: displayedWindows, activate: activate)
        positionPanel(anchorPoint: anchorPoint, panelSize: panelSize)

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.12
                panel.animator().alphaValue = 0
            },
            completionHandler: {
                self.panel.orderOut(nil)
            })
    }

    func contains(screenPoint: CGPoint) -> Bool {
        panel.isVisible && panel.frame.contains(screenPoint)
    }

    var isVisible: Bool {
        panel.isVisible
    }

    private func rebuild(
        windows: [WindowDescriptor], activate: @escaping (WindowDescriptor) -> Void
    ) {
        backgroundCardView.subviews.filter { $0 !== blurView }.forEach { $0.removeFromSuperview() }
        backgroundCardView.layoutSubtreeIfNeeded()

        let contentHeight =
            CGFloat(windows.count) * Metrics.itemSize.height
            + CGFloat(max(windows.count - 1, 0)) * Metrics.itemSpacing
        let originX = (backgroundCardView.bounds.width - Metrics.itemSize.width) / 2
        var originY =
            backgroundCardView.bounds.height
            - ((backgroundCardView.bounds.height - contentHeight) / 2)
            - Metrics.itemSize.height

        for window in windows {
            let previewView = PreviewThumbnailItemView(
                frame: NSRect(origin: .zero, size: Metrics.itemSize))
            let thumbnailSize = NSSize(width: 236, height: 132)
            let thumbnail = ThumbnailCache.shared.image(for: window, targetSize: thumbnailSize)

            previewView.frame = NSRect(
                origin: NSPoint(x: originX, y: originY), size: Metrics.itemSize)
            previewView.configure(
                with: window,
                image: thumbnail
            )
            previewView.onActivate = { [window] in
                activate(window)
            }
            backgroundCardView.addSubview(previewView)
            originY -= Metrics.itemSize.height + Metrics.itemSpacing
        }
    }

    private func layoutChrome(panelSize: NSSize) {
        rootView.frame = NSRect(origin: .zero, size: panelSize)
        backgroundCardView.frame = rootView.bounds.insetBy(
            dx: Metrics.panelInset, dy: Metrics.panelInset)
        blurView.frame = backgroundCardView.bounds
    }

    private func panelSize(for itemCount: Int) -> NSSize {
        let width =
            Metrics.contentPadding * 2
            + Metrics.itemSize.width
            + Metrics.panelInset * 2

        let height =
            Metrics.contentPadding * 2
            + CGFloat(itemCount) * Metrics.itemSize.height
            + CGFloat(max(itemCount - 1, 0)) * Metrics.itemSpacing
            + Metrics.panelInset * 2

        return NSSize(width: width, height: height)
    }

    private func positionPanel(anchorPoint: CGPoint, panelSize: NSSize) {
        guard
            let screen = NSScreen.screens.first(where: { $0.frame.contains(anchorPoint) })
                ?? NSScreen.main
        else {
            return
        }

        let edgeThreshold: CGFloat = 120
        var origin = CGPoint(x: anchorPoint.x - panelSize.width / 2, y: anchorPoint.y + 18)

        if anchorPoint.x - screen.frame.minX < edgeThreshold {
            origin = CGPoint(x: anchorPoint.x + 28, y: anchorPoint.y - panelSize.height / 2)
        } else if screen.frame.maxX - anchorPoint.x < edgeThreshold {
            origin = CGPoint(
                x: anchorPoint.x - panelSize.width - 28, y: anchorPoint.y - panelSize.height / 2)
        } else if anchorPoint.y - screen.frame.minY < edgeThreshold {
            origin = CGPoint(x: anchorPoint.x - panelSize.width / 2, y: anchorPoint.y + 28)
        } else if screen.frame.maxY - anchorPoint.y < edgeThreshold {
            origin = CGPoint(
                x: anchorPoint.x - panelSize.width / 2, y: anchorPoint.y - panelSize.height - 28)
        }

        origin.x = max(
            screen.frame.minX + 20, min(origin.x, screen.frame.maxX - panelSize.width - 20))
        origin.y = max(
            screen.frame.minY + 20, min(origin.y, screen.frame.maxY - panelSize.height - 20))

        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
    }
}
