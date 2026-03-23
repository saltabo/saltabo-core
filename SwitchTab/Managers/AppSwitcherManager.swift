import AppKit

final class AppSwitcherManager {
    static let shared = AppSwitcherManager()

    private let windowService = SpaceAwareWindowService.shared
    private let permissionService = AccessibilityService.shared
    private let floatingWindow = FloatingSwitcherWindow()

    private var eventTap: CFMachPort?
    private var items: [SwitcherApp] = []
    private var selectedIndex = 0

    private init() {}

    func start() {
        installEventTap()
    }

    func showSwitcherForCurrentSpace() {
        advanceSelection(reverse: false, explicitOpen: true)
    }

    private func installEventTap() {
        let permissions = permissionService.requestRequiredPermissions()
        guard permissions.allGranted else {
            permissionService.presentPermissionAlertIfNeeded()
            return
        }

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, _ in
                AppSwitcherManager.shared.handle(eventType: type, event: event)
            },
            userInfo: nil
        )

        guard let eventTap else {
            permissionService.presentPermissionAlertIfNeeded()
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func handle(eventType: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        if eventType == .keyDown, keyCode == 48, flags.contains(.maskCommand) {
            let reverse = flags.contains(.maskShift)
            DispatchQueue.main.async {
                self.advanceSelection(reverse: reverse, explicitOpen: false)
            }
            return nil
        }

        if eventType == .keyDown, keyCode == 53, !items.isEmpty {
            DispatchQueue.main.async {
                self.cancel()
            }
            return nil
        }

        if eventType == .flagsChanged, (keyCode == 55 || keyCode == 54), !flags.contains(.maskCommand) {
            DispatchQueue.main.async {
                self.commitSelection()
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func advanceSelection(reverse: Bool, explicitOpen: Bool) {
        if items.isEmpty || explicitOpen {
            items = windowService.currentSpaceApplications()
            guard !items.isEmpty else { return }
            ThumbnailCache.shared.warm(items.flatMap(\.windows), targetSize: NSSize(width: 236, height: 132))
            selectedIndex = items.count > 1 ? 1 : 0
            floatingWindow.show(items: items, selectedIndex: selectedIndex)
            return
        }

        let delta = reverse ? -1 : 1
        selectedIndex = (selectedIndex + delta + items.count) % items.count
        floatingWindow.update(items: items, selectedIndex: selectedIndex)
    }

    private func commitSelection() {
        defer {
            items = []
            selectedIndex = 0
            floatingWindow.hide()
        }

        guard items.indices.contains(selectedIndex) else { return }
        windowService.activate(app: items[selectedIndex])
    }

    private func cancel() {
        items = []
        selectedIndex = 0
        floatingWindow.hide()
    }
}
