import AppKit

private final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class FloatingSwitcherWindow {
    private enum ResolvedTheme {
        case light
        case dark
    }

    private enum Metrics {
        static let thumbnailItemSize = NSSize(width: 236, height: 164)
        static let appIconItemSize = NSSize(width: 128, height: 128)
        static let listItemSize = NSSize(width: 620, height: 52)
        static let itemSpacing: CGFloat = 8
        static let listItemSpacing: CGFloat = 5
        static let contentInset = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        static let listContentInset = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        static let panelInset: CGFloat = 12
        static let thumbnailCacheTargetSize = NSSize(width: 212, height: 124)
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
        rebuild(items: items, selectedIndex: selectedIndex, onHoverIndex: nil, onActivateIndex: nil)

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
        rebuild(items: items, selectedIndex: selectedIndex, onHoverIndex: nil, onActivateIndex: nil)
        panel.displayIfNeeded()
    }

    func show(
        items: [SwitcherApp],
        selectedIndex: Int,
        onHoverIndex: @escaping (Int) -> Void,
        onActivateIndex: @escaping (Int) -> Void
    ) {
        guard !items.isEmpty else { return }

        let panelSize = panelSize(for: items.count)
        layoutChrome(panelSize: panelSize)
        rebuild(
            items: items,
            selectedIndex: selectedIndex,
            onHoverIndex: onHoverIndex,
            onActivateIndex: onActivateIndex
        )

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

    func update(
        items: [SwitcherApp],
        selectedIndex: Int,
        onHoverIndex: @escaping (Int) -> Void,
        onActivateIndex: @escaping (Int) -> Void
    ) {
        guard !items.isEmpty else { return }
        let panelSize = panelSize(for: items.count)
        layoutChrome(panelSize: panelSize)
        rebuild(
            items: items,
            selectedIndex: selectedIndex,
            onHoverIndex: onHoverIndex,
            onActivateIndex: onActivateIndex
        )
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

    func contains(screenPoint: NSPoint) -> Bool {
        panel.isVisible && panel.frame.contains(screenPoint)
    }

    private func rebuild(
        items: [SwitcherApp],
        selectedIndex: Int,
        onHoverIndex: ((Int) -> Void)?,
        onActivateIndex: ((Int) -> Void)?
    ) {
        let itemSize = currentItemSize()
        let displayStyle = AppSettings.shared.switcherDisplayStyle
        let isList = displayStyle == .list
        let contentInset = isList ? Metrics.listContentInset : Metrics.contentInset
        let itemSpacing = isList ? Metrics.listItemSpacing : Metrics.itemSpacing
        backgroundCardView.subviews
            .filter { $0 !== blurView && $0 !== tintView }
            .forEach { $0.removeFromSuperview() }

        var originX = contentInset.left
        var originY = contentInset.bottom
        if isList {
            originY = backgroundCardView.bounds.height - contentInset.top - itemSize.height
        }

        for (index, item) in items.enumerated() {
            let view = AppSwitcherItemView(frame: NSRect(origin: .zero, size: itemSize))
            view.configure(
                with: item,
                selected: index == selectedIndex,
                displayStyle: displayStyle,
            )
            view.onHover = {
                onHoverIndex?(index)
            }
            view.onActivate = {
                onActivateIndex?(index)
            }
            view.frame = NSRect(origin: NSPoint(x: originX, y: originY), size: itemSize)
            backgroundCardView.addSubview(view)
            if isList {
                originY -= itemSize.height + itemSpacing
            } else {
                originX += itemSize.width + itemSpacing
            }
        }
    }

    private func layoutChrome(panelSize: NSSize) {
        applyThemeAppearance()
        rootView.frame = NSRect(origin: .zero, size: panelSize)
        backgroundCardView.frame = rootView.bounds.insetBy(
            dx: Metrics.panelInset, dy: Metrics.panelInset)
        blurView.frame = backgroundCardView.bounds
        tintView.frame = backgroundCardView.bounds
    }

    private func panelSize(for itemCount: Int) -> NSSize {
        let itemSize = currentItemSize()
        let displayStyle = AppSettings.shared.switcherDisplayStyle
        let isList = displayStyle == .list
        let contentInset = isList ? Metrics.listContentInset : Metrics.contentInset
        let itemSpacing = isList ? Metrics.listItemSpacing : Metrics.itemSpacing
        if isList {
            let width =
                contentInset.left + contentInset.right + itemSize.width + Metrics.panelInset * 2
            let height =
                contentInset.top + contentInset.bottom
                + CGFloat(itemCount) * itemSize.height
                + CGFloat(max(itemCount - 1, 0)) * itemSpacing
                + Metrics.panelInset * 2
            return NSSize(width: width, height: height)
        }
        let contentWidth =
            contentInset.left
            + contentInset.right
            + CGFloat(itemCount) * itemSize.width
            + CGFloat(max(itemCount - 1, 0)) * itemSpacing
        let contentHeight = contentInset.top + contentInset.bottom + itemSize.height
        let minimumWidth =
            itemSize.width + contentInset.left + contentInset.right
            + Metrics.panelInset * 2
        let width = max(minimumWidth, contentWidth + Metrics.panelInset * 2)
        return NSSize(width: width, height: contentHeight + Metrics.panelInset * 2)
    }

    private func currentItemSize() -> NSSize {
        let baseSize =
            switch AppSettings.shared.switcherDisplayStyle {
            case .thumbnails:
                Metrics.thumbnailItemSize
            case .appIcons:
                Metrics.appIconItemSize
            case .list:
                Metrics.listItemSize
            }
        let scale = Self.resolvedScale(for: AppSettings.shared.switcherSizePreset)
        return NSSize(
            width: round(baseSize.width * scale),
            height: round(baseSize.height * scale)
        )
    }

    static func thumbnailCacheTargetSizeForCurrentPreset() -> NSSize {
        let scale = resolvedScale(for: AppSettings.shared.switcherSizePreset)
        return NSSize(
            width: round(Metrics.thumbnailCacheTargetSize.width * scale),
            height: round(Metrics.thumbnailCacheTargetSize.height * scale)
        )
    }

    private static func resolvedScale(for preset: SwitcherSizePreset) -> CGFloat {
        switch preset {
        case .small:
            return 0.88
        case .medium:
            return 1.0
        case .large:
            return 1.14
        case .auto:
            let width = NSScreen.main?.visibleFrame.width ?? 1512
            if width >= 2200 { return 1.14 }
            if width <= 1350 { return 0.88 }
            return 1.0
        }
    }

    private func applyThemeAppearance() {
        switch resolvedTheme() {
        case .light:
            backgroundCardView.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
            backgroundCardView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.28).cgColor
            blurView.material = .sidebar
            tintView.layer?.backgroundColor =
                NSColor(calibratedRed: 0.36, green: 0.50, blue: 0.88, alpha: 0.22).cgColor

        case .dark:
            backgroundCardView.layer?.borderColor = NSColor.white.withAlphaComponent(0.28).cgColor
            backgroundCardView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.52).cgColor
            blurView.material = .hudWindow
            tintView.layer?.backgroundColor =
                NSColor(calibratedRed: 0.22, green: 0.29, blue: 0.46, alpha: 0.40).cgColor
        }
    }

    private func resolvedTheme() -> ResolvedTheme {
        switch AppSettings.shared.switcherThemePreset {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            let best = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            return best == .darkAqua ? .dark : .light
        }
    }

    private func screenForPresentation() -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }
}
