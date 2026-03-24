import AppKit

final class AppSwitcherItemView: NSView {
    private enum Metrics {
        static let itemSize = NSSize(width: 236, height: 164)
        static let contentInset: CGFloat = 8
        static let titleBarHeight: CGFloat = 28
        static let previewSpacing: CGFloat = 4
        static let thumbnailTargetSize = NSSize(width: 212, height: 124)
        static let titleIconSize: CGFloat = 24
    }

    override var intrinsicContentSize: NSSize {
        Metrics.itemSize
    }

    private let contentCardView = NSView()
    private let titleBarView = NSView()
    private let titleIconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let previewClipView = NSView()
    private let previewImageView = NSImageView()
    private let placeholderView = NSView()
    private let placeholderIconWellView = NSView()
    private let placeholderIconView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(origin: .zero, size: Metrics.itemSize))
        wantsLayer = true
        layer?.cornerRadius = 22

        contentCardView.wantsLayer = true
        contentCardView.layer?.cornerRadius = 18
        contentCardView.layer?.masksToBounds = true

        titleBarView.wantsLayer = true
        titleBarView.layer?.cornerRadius = 12
        titleBarView.layer?.masksToBounds = true

        titleIconView.imageScaling = .scaleProportionallyUpOrDown

        titleField.font = .systemFont(ofSize: 13, weight: .medium)
        titleField.textColor = NSColor(calibratedWhite: 0.16, alpha: 0.92)
        titleField.lineBreakMode = .byTruncatingTail

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

        addSubview(contentCardView)
        contentCardView.addSubview(titleBarView)
        titleBarView.addSubview(titleIconView)
        titleBarView.addSubview(titleField)
        contentCardView.addSubview(previewClipView)
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

        contentCardView.frame = bounds.insetBy(dx: 8, dy: 8)

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
    }

    func configure(with item: SwitcherApp, selected: Bool) {
        let window = item.primaryWindow
        titleField.stringValue = window.displayTitle
        titleIconView.image = item.icon
        placeholderIconView.image = item.icon

        let thumbnail = ThumbnailCache.shared.image(
            for: window,
            targetSize: Metrics.thumbnailTargetSize
        )
        previewImageView.image = thumbnail
        previewImageView.isHidden = (thumbnail == nil)
        placeholderView.isHidden = (thumbnail != nil)

        contentCardView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.94).cgColor
        titleBarView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.98).cgColor
        previewClipView.layer?.backgroundColor = NSColor(calibratedWhite: 0.90, alpha: 0.94).cgColor

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
    }
}
