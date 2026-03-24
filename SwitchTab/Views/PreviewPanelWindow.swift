import AppKit

final class PreviewPanelWindow {
    private let panel: NSPanel
    private let rootView = TransparentPanelContentView()
    private let visualEffectView = NSVisualEffectView()
    private let stackView = NSStackView()

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 240),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.alphaValue = 1
        panel.hasShadow = false

        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.clear.cgColor
        rootView.frame = panel.contentRect(forFrameRect: panel.frame)

        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 24
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false

        stackView.orientation = .horizontal
        stackView.spacing = 14
        stackView.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(visualEffectView)
        visualEffectView.addSubview(stackView)
        panel.contentView = rootView

        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 8),
            visualEffectView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 8),
            visualEffectView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -8),
            visualEffectView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -8),

            stackView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
        ])
    }

    func show(
        windows: [WindowDescriptor],
        appName: String,
        anchorPoint: CGPoint,
        activate: @escaping (WindowDescriptor) -> Void
    ) {
        rebuild(windows: windows, activate: activate)
        positionPanel(anchorPoint: anchorPoint, itemCount: windows.count)
        rootView.frame = panel.contentRect(forFrameRect: panel.frame)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: {
            self.panel.orderOut(nil)
        })
    }

    private func rebuild(windows: [WindowDescriptor], activate: @escaping (WindowDescriptor) -> Void) {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for window in windows.prefix(6) {
            let previewView = PreviewThumbnailItemView()
            let size = NSSize(width: 236, height: 132)
            let thumbnail = ThumbnailCache.shared.image(for: window, targetSize: size)
            let subtitle = AccessibilityService.shared.browserTabTitles(for: window.pid)
                .filter { !$0.isEmpty }
                .prefix(2)
                .joined(separator: " • ")
            previewView.configure(
                with: window,
                subtitle: subtitle.isEmpty ? window.appName : subtitle,
                image: thumbnail
            )
            previewView.onActivate = {
                activate(window)
            }
            stackView.addArrangedSubview(previewView)
        }
    }

    private func positionPanel(anchorPoint: CGPoint, itemCount: Int) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(anchorPoint) }) ?? NSScreen.main else {
            return
        }

        let width = min(max(CGFloat(itemCount) * 274 + 36, 320), screen.frame.width - 60)
        let height: CGFloat = 246
        var origin = CGPoint(x: anchorPoint.x - width / 2, y: anchorPoint.y + 18)

        origin.x = max(screen.frame.minX + 20, min(origin.x, screen.frame.maxX - width - 20))
        origin.y = max(screen.frame.minY + 20, min(origin.y, screen.frame.maxY - height - 20))

        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
    }
}
