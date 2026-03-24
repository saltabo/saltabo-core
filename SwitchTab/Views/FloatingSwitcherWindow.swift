import AppKit

private final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class FloatingSwitcherWindow {
    private enum Metrics {
        static let itemSize = NSSize(width: 236, height: 164)
        static let itemSpacing: CGFloat = 14
        static let contentInset = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        static let panelInset: CGFloat = 12
    }

    private let panel: NSPanel
    private let rootView = TransparentPanelContentView()
    private let backgroundCardView = NSView()
    private let blurView = NSVisualEffectView()
    private let tintView = NSView()

    init() {
        panel = SwitcherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 208),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false

        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.clear.cgColor

        backgroundCardView.wantsLayer = true
        backgroundCardView.layer?.cornerRadius = 24
        backgroundCardView.layer?.masksToBounds = true
        backgroundCardView.layer?.backgroundColor = NSColor.clear.cgColor
        backgroundCardView.layer?.borderWidth = 1
        backgroundCardView.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        backgroundCardView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.28).cgColor
        backgroundCardView.layer?.shadowOpacity = 1
        backgroundCardView.layer?.shadowRadius = 24
        backgroundCardView.layer?.shadowOffset = NSSize(width: 0, height: -8)

        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.material = .sidebar
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = 24
        blurView.layer?.masksToBounds = true

        tintView.wantsLayer = true
        tintView.layer?.backgroundColor =
            NSColor(calibratedRed: 0.36, green: 0.50, blue: 0.88, alpha: 0.22).cgColor

        rootView.addSubview(backgroundCardView)
        backgroundCardView.addSubview(blurView)
        backgroundCardView.addSubview(tintView)
        panel.contentView = rootView
    }

    func show(items: [SwitcherApp], selectedIndex: Int) {
        guard !items.isEmpty else { return }

        let panelSize = panelSize(for: items.count)
        layoutChrome(panelSize: panelSize)
        rebuild(items: items, selectedIndex: selectedIndex)

        guard let screen = screenForPresentation() else { return }
        let frame = NSRect(
            x: screen.visibleFrame.midX - panelSize.width / 2,
            y: screen.visibleFrame.midY - panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )

        panel.setFrame(frame, display: false)
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func update(items: [SwitcherApp], selectedIndex: Int) {
        guard !items.isEmpty else { return }
        let panelSize = panelSize(for: items.count)
        layoutChrome(panelSize: panelSize)
        rebuild(items: items, selectedIndex: selectedIndex)
        panel.displayIfNeeded()
    }

    func hide() {
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.1
                panel.animator().alphaValue = 0
            },
            completionHandler: {
                self.panel.orderOut(nil)
            })
    }

    private func rebuild(items: [SwitcherApp], selectedIndex: Int) {
        backgroundCardView.subviews
            .filter { $0 !== blurView && $0 !== tintView }
            .forEach { $0.removeFromSuperview() }

        let originY = Metrics.contentInset.bottom
        var originX = Metrics.contentInset.left

        for (index, item) in items.enumerated() {
            let view = AppSwitcherItemView(frame: NSRect(origin: .zero, size: Metrics.itemSize))
            view.configure(with: item, selected: index == selectedIndex)
            view.frame = NSRect(origin: NSPoint(x: originX, y: originY), size: Metrics.itemSize)
            backgroundCardView.addSubview(view)
            originX += Metrics.itemSize.width + Metrics.itemSpacing
        }
    }

    private func layoutChrome(panelSize: NSSize) {
        rootView.frame = NSRect(origin: .zero, size: panelSize)
        backgroundCardView.frame = rootView.bounds.insetBy(
            dx: Metrics.panelInset, dy: Metrics.panelInset)
        blurView.frame = backgroundCardView.bounds
        tintView.frame = backgroundCardView.bounds
    }

    private func panelSize(for itemCount: Int) -> NSSize {
        let contentWidth =
            Metrics.contentInset.left
            + Metrics.contentInset.right
            + CGFloat(itemCount) * Metrics.itemSize.width
            + CGFloat(max(itemCount - 1, 0)) * Metrics.itemSpacing
        let contentHeight = Metrics.contentInset.top + Metrics.contentInset.bottom + Metrics.itemSize.height
        let minimumWidth =
            Metrics.itemSize.width + Metrics.contentInset.left + Metrics.contentInset.right
            + Metrics.panelInset * 2
        let width = max(minimumWidth, contentWidth + Metrics.panelInset * 2)
        return NSSize(width: width, height: contentHeight + Metrics.panelInset * 2)
    }

    private func screenForPresentation() -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }
}
