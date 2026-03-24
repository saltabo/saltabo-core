import AppKit

final class AppSwitcherItemView: NSView {
    override var intrinsicContentSize: NSSize {
        NSSize(width: 152, height: 108)
    }

    private let iconView = NSImageView()
    private let iconWellView = NSView()
    private let titleField = NSTextField(labelWithString: "")
    private let subtitleField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: 152, height: 108)))
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.borderWidth = 1
        layer?.backgroundColor = NSColor(calibratedWhite: 0.14, alpha: 0.62).cgColor
        layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor

        iconWellView.translatesAutoresizingMaskIntoConstraints = false
        iconWellView.wantsLayer = true
        iconWellView.layer?.cornerRadius = 14
        iconWellView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.90).cgColor
        iconWellView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.12).cgColor
        iconWellView.layer?.shadowOpacity = 1
        iconWellView.layer?.shadowRadius = 10
        iconWellView.layer?.shadowOffset = NSSize(width: 0, height: -2)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.font = .systemFont(ofSize: 14, weight: .semibold)
        titleField.textColor = NSColor.white.withAlphaComponent(0.96)
        titleField.lineBreakMode = .byTruncatingTail

        subtitleField.translatesAutoresizingMaskIntoConstraints = false
        subtitleField.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleField.textColor = NSColor.white.withAlphaComponent(0.62)
        subtitleField.lineBreakMode = .byTruncatingTail

        addSubview(iconWellView)
        addSubview(iconView)
        addSubview(titleField)
        addSubview(subtitleField)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 152),
            heightAnchor.constraint(equalToConstant: 108),

            iconWellView.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            iconWellView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconWellView.widthAnchor.constraint(equalToConstant: 42),
            iconWellView.heightAnchor.constraint(equalToConstant: 42),

            iconView.centerXAnchor.constraint(equalTo: iconWellView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconWellView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            titleField.topAnchor.constraint(equalTo: iconWellView.bottomAnchor, constant: 12),
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            subtitleField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 4),
            subtitleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            subtitleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(with item: SwitcherApp, selected: Bool) {
        iconView.image = item.icon
        titleField.stringValue = item.appName
        subtitleField.stringValue = item.subtitle
        layer?.backgroundColor = (selected
            ? NSColor.controlAccentColor.withAlphaComponent(0.28)
            : NSColor(calibratedWhite: 0.14, alpha: 0.72)).cgColor
        layer?.borderColor = (selected
            ? NSColor.controlAccentColor.withAlphaComponent(0.96)
            : NSColor.white.withAlphaComponent(0.12)).cgColor
        layer?.shadowColor = (selected ? NSColor.controlAccentColor.withAlphaComponent(0.28) : NSColor.black.withAlphaComponent(0.12)).cgColor
        layer?.shadowOpacity = 1
        layer?.shadowRadius = selected ? 16 : 8
        layer?.shadowOffset = NSSize(width: 0, height: -2)
        alphaValue = 1
    }
}
