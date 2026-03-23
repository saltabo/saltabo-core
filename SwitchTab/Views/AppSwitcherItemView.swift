import AppKit

final class AppSwitcherItemView: NSView {
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let subtitleField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.borderWidth = 1

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.font = .systemFont(ofSize: 14, weight: .semibold)
        titleField.lineBreakMode = .byTruncatingTail

        subtitleField.translatesAutoresizingMaskIntoConstraints = false
        subtitleField.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleField.textColor = .secondaryLabelColor
        subtitleField.lineBreakMode = .byTruncatingTail

        addSubview(iconView)
        addSubview(titleField)
        addSubview(subtitleField)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 152),
            heightAnchor.constraint(equalToConstant: 108),

            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 42),
            iconView.heightAnchor.constraint(equalToConstant: 42),

            titleField.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
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
        layer?.backgroundColor = (selected ? NSColor.controlAccentColor.withAlphaComponent(0.14) : NSColor.white.withAlphaComponent(0.08)).cgColor
        layer?.borderColor = (selected ? NSColor.controlAccentColor : NSColor.white.withAlphaComponent(0.08)).cgColor
        alphaValue = selected ? 1 : 0.9
    }
}
