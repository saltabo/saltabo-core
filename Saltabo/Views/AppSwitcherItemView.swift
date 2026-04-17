import AppKit

final class AppSwitcherItemView: NSView {
    private enum ResolvedTheme {
        case light
        case dark
    }

    var onHover: (() -> Void)?
    var onActivate: (() -> Void)?

    private enum Metrics {
        static let itemSize = NSSize(width: 236, height: 164)
        static let contentInset: CGFloat = 8
        static let appIconInset: CGFloat = 0
        static let titleBarHeight: CGFloat = 28
        static let previewSpacing: CGFloat = 4
        static let titleIconSize: CGFloat = 24
        static let listIconSize: CGFloat = 28
        static let defaultOuterCornerRadius: CGFloat = 18
        static let defaultContentCornerRadius: CGFloat = 14
        static let listOuterCornerRadius: CGFloat = 12
        static let listContentCornerRadius: CGFloat = 10
        static let listContentInset: CGFloat = 4
    }

    override var intrinsicContentSize: NSSize {
        Metrics.itemSize
    }

    private let contentCardView = NSView()
    private let titleBarView = NSView()
    private let titleIconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let listIconView = NSImageView()
    private let listTitleField = NSTextField(labelWithString: "")
    private let listSubtitleField = NSTextField(labelWithString: "")
    private let previewClipView = NSView()
    private let previewImageView = NSImageView()
    private let placeholderView = NSView()
    private let placeholderIconWellView = NSView()
    private let placeholderIconView = NSImageView()
    private let largeAppIconView = NSImageView()
    private let listTrailingBadgeField = NSTextField(labelWithString: "")
    private var displayStyle: SwitcherDisplayStyle = .thumbnails
    private var trackingAreaRef: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(origin: .zero, size: Metrics.itemSize))
        wantsLayer = true
        layer?.cornerRadius = Metrics.defaultOuterCornerRadius

        contentCardView.wantsLayer = true
        contentCardView.layer?.cornerRadius = Metrics.defaultContentCornerRadius
        contentCardView.layer?.masksToBounds = true

        titleBarView.wantsLayer = true
        titleBarView.layer?.cornerRadius = 12
        titleBarView.layer?.masksToBounds = true

        titleIconView.imageScaling = .scaleProportionallyUpOrDown

        titleField.font = .systemFont(ofSize: 13, weight: .medium)
        titleField.textColor = NSColor(calibratedWhite: 0.16, alpha: 0.92)
        titleField.lineBreakMode = .byTruncatingTail

        listIconView.imageScaling = .scaleProportionallyUpOrDown
        listTitleField.font = .systemFont(ofSize: 13, weight: .semibold)
        listTitleField.lineBreakMode = .byTruncatingTail
        listSubtitleField.font = .systemFont(ofSize: 12, weight: .regular)
        listSubtitleField.lineBreakMode = .byTruncatingTail

        previewClipView.wantsLayer = true
        // previewClipView.layer?.cornerRadius = 14
        previewClipView.layer?.masksToBounds = true

        previewImageView.imageScaling = .scaleAxesIndependently

        placeholderView.wantsLayer = true
        placeholderView.layer?.backgroundColor = NSColor(calibratedWhite: 0.86, alpha: 0.96).cgColor

        placeholderIconWellView.wantsLayer = true
        placeholderIconWellView.layer?.cornerRadius = 14
        placeholderIconWellView.layer?.backgroundColor =
            NSColor.white.withAlphaComponent(0.96).cgColor
        placeholderIconWellView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.10).cgColor
        placeholderIconWellView.layer?.shadowOpacity = 1
        placeholderIconWellView.layer?.shadowRadius = 10
        placeholderIconWellView.layer?.shadowOffset = NSSize(width: 0, height: -2)

        placeholderIconView.imageScaling = .scaleProportionallyUpOrDown

        largeAppIconView.imageScaling = .scaleProportionallyUpOrDown
        largeAppIconView.isHidden = true

        listTrailingBadgeField.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        listTrailingBadgeField.alignment = .right
        listTrailingBadgeField.textColor = NSColor.secondaryLabelColor

        addSubview(contentCardView)
        contentCardView.addSubview(titleBarView)
        titleBarView.addSubview(titleIconView)
        titleBarView.addSubview(titleField)
        contentCardView.addSubview(previewClipView)
        contentCardView.addSubview(largeAppIconView)
        contentCardView.addSubview(listIconView)
        contentCardView.addSubview(listTitleField)
        contentCardView.addSubview(listSubtitleField)
        contentCardView.addSubview(listTrailingBadgeField)
        previewClipView.addSubview(placeholderView)
        previewClipView.addSubview(previewImageView)
        placeholderView.addSubview(placeholderIconWellView)
        placeholderIconWellView.addSubview(placeholderIconView)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()

        switch displayStyle {
        case .appIcons:
            contentCardView.frame = bounds
            titleBarView.isHidden = true
            previewClipView.isHidden = true
            largeAppIconView.isHidden = false
            listIconView.isHidden = true
            listTitleField.isHidden = true
            listSubtitleField.isHidden = true
            listTrailingBadgeField.isHidden = true
            largeAppIconView.frame = contentCardView.bounds.insetBy(
                dx: Metrics.appIconInset,
                dy: Metrics.appIconInset
            )

        case .thumbnails:
            contentCardView.frame = bounds.insetBy(dx: 8, dy: 8)
            titleBarView.isHidden = false
            previewClipView.isHidden = false
            largeAppIconView.isHidden = true
            listIconView.isHidden = true
            listTitleField.isHidden = true
            listSubtitleField.isHidden = true
            listTrailingBadgeField.isHidden = true

            let titleBarFrame = NSRect(
                x: Metrics.contentInset,
                y: contentCardView.bounds.height - Metrics.contentInset - Metrics.titleBarHeight,
                width: contentCardView.bounds.width - (Metrics.contentInset * 2),
                height: Metrics.titleBarHeight
            )
            titleBarView.frame = titleBarFrame

            titleIconView.frame = NSRect(
                x: 0,
                y: (Metrics.titleBarHeight - Metrics.titleIconSize) / 2,
                width: Metrics.titleIconSize,
                height: Metrics.titleIconSize
            )
            titleField.frame = NSRect(
                x: Metrics.titleIconSize + 8,
                y: 4,
                width: titleBarFrame.width - (Metrics.titleIconSize + 16),
                height: Metrics.titleBarHeight - 8
            )

            let previewFrame = NSRect(
                x: 0,
                y: 0,
                width: contentCardView.bounds.width,
                height: titleBarFrame.minY - Metrics.previewSpacing
            )
            previewClipView.frame = previewFrame
            previewImageView.frame = previewClipView.bounds
            placeholderView.frame = previewClipView.bounds

            let iconWellSize: CGFloat = 44
            placeholderIconWellView.frame = NSRect(
                x: (previewClipView.bounds.width - iconWellSize) / 2,
                y: (previewClipView.bounds.height - iconWellSize) / 2,
                width: iconWellSize,
                height: iconWellSize
            )
            placeholderIconView.frame = NSRect(x: 8, y: 8, width: 28, height: 28)

        case .list:
            contentCardView.frame = bounds.insetBy(
                dx: Metrics.listContentInset,
                dy: Metrics.listContentInset
            )
            titleBarView.isHidden = true
            previewClipView.isHidden = true
            largeAppIconView.isHidden = true
            listIconView.isHidden = false
            listTitleField.isHidden = false
            listSubtitleField.isHidden = false
            listTrailingBadgeField.isHidden = false

            listIconView.frame = NSRect(
                x: 14,
                y: (contentCardView.bounds.height - Metrics.listIconSize) / 2,
                width: Metrics.listIconSize,
                height: Metrics.listIconSize
            )
            listTitleField.frame = NSRect(
                x: listIconView.frame.maxX + 10,
                y: (contentCardView.bounds.height / 2) - 1,
                width: max(120, contentCardView.bounds.width - 140),
                height: 17
            )
            listSubtitleField.frame = NSRect(
                x: listIconView.frame.maxX + 10,
                y: (contentCardView.bounds.height / 2) - 16,
                width: max(120, contentCardView.bounds.width - 140),
                height: 14
            )
            listTrailingBadgeField.frame = NSRect(
                x: contentCardView.bounds.width - 34,
                y: 0,
                width: 24,
                height: contentCardView.bounds.height
            )
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // `point` is in the superview's coordinate system; `bounds` is local.
        guard let superview else { return super.hitTest(point) }
        let localPoint = convert(point, from: superview)
        return bounds.contains(localPoint) ? self : nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let tracking = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking)
        trackingAreaRef = tracking
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        onActivate?()
    }

    func configure(
        with item: SwitcherApp,
        selected: Bool,
        displayStyle: SwitcherDisplayStyle,
        trailingBadgeText: String? = nil
    ) {
        self.displayStyle = displayStyle
        if displayStyle == .list {
            layer?.cornerRadius = Metrics.listOuterCornerRadius
            contentCardView.layer?.cornerRadius = Metrics.listContentCornerRadius
        } else {
            layer?.cornerRadius = Metrics.defaultOuterCornerRadius
            contentCardView.layer?.cornerRadius = Metrics.defaultContentCornerRadius
        }
        let window = item.primaryWindow
        titleField.stringValue = window.displayTitle
        listTitleField.stringValue = item.appName
        listSubtitleField.stringValue =
            window.displayTitle.isEmpty ? "Current Space" : window.displayTitle
        titleIconView.image = item.icon
        listIconView.image = item.icon
        placeholderIconView.image = item.icon
        largeAppIconView.image = item.icon
        listTrailingBadgeField.stringValue = trailingBadgeText ?? ""

        switch displayStyle {
        case .thumbnails:
            let thumbnailTargetSize = NSSize(
                width: max(120, bounds.width - 24),
                height: max(80, bounds.height - 40)
            )
            let thumbnail = ThumbnailCache.shared.image(
                for: window,
                targetSize: thumbnailTargetSize
            )
            previewImageView.image = thumbnail
            previewImageView.isHidden = (thumbnail == nil)
            placeholderView.isHidden = (thumbnail != nil)

        case .appIcons:
            previewImageView.image = nil
            previewImageView.isHidden = true
            placeholderView.isHidden = false

        case .list:
            previewImageView.image = nil
            previewImageView.isHidden = true
            placeholderView.isHidden = true
        }

        let resolvedTheme = resolvedTheme()
        switch resolvedTheme {
        case .light:
            titleField.textColor = NSColor(calibratedWhite: 0.16, alpha: 0.92)
            listTitleField.textColor = NSColor(calibratedWhite: 0.20, alpha: 0.94)
            listSubtitleField.textColor = NSColor(calibratedWhite: 0.44, alpha: 0.90)
            listTrailingBadgeField.textColor = NSColor.secondaryLabelColor
            placeholderView.layer?.backgroundColor =
                NSColor(calibratedWhite: 0.86, alpha: 0.96).cgColor
            placeholderIconWellView.layer?.backgroundColor =
                NSColor.white.withAlphaComponent(0.96).cgColor
            contentCardView.layer?.backgroundColor =
                (displayStyle == .appIcons
                ? NSColor.clear
                : NSColor.white.withAlphaComponent(displayStyle == .list ? 0.88 : 0.94))
                .cgColor
            titleBarView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.98).cgColor
            previewClipView.layer?.backgroundColor =
                NSColor(calibratedWhite: 0.90, alpha: 0.94).cgColor

        case .dark:
            titleField.textColor = NSColor(calibratedWhite: 0.92, alpha: 0.95)
            listTitleField.textColor = NSColor(calibratedWhite: 0.93, alpha: 0.98)
            listSubtitleField.textColor = NSColor(calibratedWhite: 0.64, alpha: 0.94)
            listTrailingBadgeField.textColor = NSColor(calibratedWhite: 0.72, alpha: 0.95)
            placeholderView.layer?.backgroundColor =
                NSColor(calibratedWhite: 0.18, alpha: 0.94).cgColor
            placeholderIconWellView.layer?.backgroundColor =
                NSColor(calibratedWhite: 0.26, alpha: 0.98).cgColor
            contentCardView.layer?.backgroundColor =
                (displayStyle == .appIcons
                ? NSColor.clear
                : NSColor(calibratedWhite: displayStyle == .list ? 0.22 : 0.16, alpha: 0.92))
                .cgColor
            titleBarView.layer?.backgroundColor =
                NSColor(calibratedWhite: 0.22, alpha: 0.96).cgColor
            previewClipView.layer?.backgroundColor =
                NSColor(calibratedWhite: 0.12, alpha: 0.94).cgColor
        }

        layer?.backgroundColor =
            (selected
            ? NSColor.controlAccentColor.withAlphaComponent(0.16)
            : NSColor.clear).cgColor
        layer?.borderColor =
            (selected
            ? NSColor.controlAccentColor.withAlphaComponent(0.94)
            : NSColor.white.withAlphaComponent(0.18)).cgColor
        layer?.borderWidth = selected ? 2.5 : 1
        layer?.shadowColor =
            (selected
            ? NSColor.controlAccentColor.withAlphaComponent(0.28)
            : NSColor.black.withAlphaComponent(0.10)).cgColor
        layer?.shadowOpacity = 1
        layer?.shadowRadius = selected ? 16 : 10
        layer?.shadowOffset = NSSize(width: 0, height: -2)

        needsLayout = true
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
}
