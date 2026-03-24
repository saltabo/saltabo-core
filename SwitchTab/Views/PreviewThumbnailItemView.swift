import AppKit

final class PreviewThumbnailItemView: NSView {
    var onActivate: (() -> Void)?

    private let imageView = NSImageView()
    private let placeholderIconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let subtitleField = NSTextField(labelWithString: "")
    private let hoverLayer = CALayer()
    private var trackingAreaRef: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = false
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.72).cgColor
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.24).cgColor
        layer?.shadowOpacity = 1
        layer?.shadowRadius = 18
        layer?.shadowOffset = CGSize(width: 0, height: -4)

        hoverLayer.cornerRadius = 16
        hoverLayer.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.0).cgColor
        layer?.addSublayer(hoverLayer)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleAxesIndependently
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 12
        imageView.layer?.masksToBounds = true
        imageView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.08).cgColor

        placeholderIconView.translatesAutoresizingMaskIntoConstraints = false
        placeholderIconView.imageScaling = .scaleProportionallyUpOrDown
        placeholderIconView.isHidden = true

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.font = .systemFont(ofSize: 13, weight: .semibold)
        titleField.textColor = NSColor.labelColor
        titleField.lineBreakMode = .byTruncatingTail

        subtitleField.translatesAutoresizingMaskIntoConstraints = false
        subtitleField.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleField.textColor = .secondaryLabelColor
        subtitleField.lineBreakMode = .byTruncatingTail

        addSubview(imageView)
        addSubview(placeholderIconView)
        addSubview(titleField)
        addSubview(subtitleField)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 260),
            heightAnchor.constraint(equalToConstant: 190),

            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            imageView.heightAnchor.constraint(equalToConstant: 132),

            placeholderIconView.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            placeholderIconView.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            placeholderIconView.widthAnchor.constraint(equalToConstant: 42),
            placeholderIconView.heightAnchor.constraint(equalToConstant: 42),

            titleField.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 10),
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            subtitleField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 4),
            subtitleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            subtitleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        hoverLayer.frame = bounds
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
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
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            hoverLayer.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
            layer?.borderWidth = 1
            layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.7).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            hoverLayer.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.0).cgColor
            layer?.borderWidth = 0
            layer?.borderColor = NSColor.clear.cgColor
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        onActivate?()
    }

    func configure(with window: WindowDescriptor, subtitle: String, image: NSImage?) {
        titleField.stringValue = window.displayTitle
        subtitleField.stringValue = subtitle
        imageView.image = image
        placeholderIconView.image = window.icon
        placeholderIconView.isHidden = image != nil
    }
}
