import AppKit

final class TransparentPanelContentView: NSView {
    override var isOpaque: Bool {
        false
    }
}
