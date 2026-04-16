import AppKit

final class AppSwitcherManager {
    static let shared = AppSwitcherManager()

    private let windowService = SpaceAwareWindowService.shared
    private let permissionService = AccessibilityService.shared
    private let floatingWindow = FloatingSwitcherWindow()

    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var items: [SwitcherApp] = []
    private var selectedIndex = 0
    private var cycleOrder: [pid_t] = []
    /// After keyboard-driven selection, ignore hover until the user actually moves the mouse
    /// (rebuilds re-deliver `mouseEntered` for the view under the cursor and would snap selection).
    private var suppressHoverSelection = false
    private var mouseMoveMonitor: Any?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShortcutChange),
            name: .switcherShortcutDidChange,
            object: nil
        )
    }

    func start() {
        teardownEventTap()
        installEventTap()
    }

    @objc private func handleShortcutChange() {
        start()
    }

    func showSwitcherForCurrentSpace() {
        advanceSelection(reverse: false, explicitOpen: true)
    }

    private func installEventTap() {
        let permissions = permissionService.currentPermissionSnapshot()
        guard permissions.corePermissionsGranted(for: AppSettings.shared.switcherShortcut) else {
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
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        eventTapSource = source
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

        let shortcut = AppSettings.shared.switcherShortcut
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        if eventType == .keyDown, shortcut.matches(tabKeyCode: keyCode, flags: flags) {
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

        if eventType == .flagsChanged,
            shortcut.matchesModifierRelease(keyCode: keyCode, flags: flags)
        {
            DispatchQueue.main.async {
                self.commitSelection()
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func teardownEventTap() {
        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), eventTapSource, .commonModes)
            self.eventTapSource = nil
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    private func advanceSelection(reverse: Bool, explicitOpen: Bool) {
        if items.isEmpty || explicitOpen {
            items = stabilizedCycleItems(from: windowService.currentSpaceApplications(on: activeScreen()))
            guard !items.isEmpty else { return }
            SettingsWindowController.shared.suppressForSwitcherIfVisible()
            ThumbnailCache.shared.warm(items.flatMap(\.windows), targetSize: NSSize(width: 236, height: 132))
            selectedIndex = nextSelectionIndex(in: items, reverse: reverse)
            // Menu-driven open: allow hover. Shortcut-driven open: keyboard owns selection until mouse moves.
            suppressHoverSelection = !explicitOpen
            floatingWindow.show(
                items: items,
                selectedIndex: selectedIndex,
                onHoverIndex: { [weak self] index in
                    self?.selectByHover(index: index)
                },
                onActivateIndex: { [weak self] index in
                    self?.activateByClick(index: index)
                }
            )
            installMouseMoveMonitorIfNeeded()
            return
        }

        let delta = reverse ? -1 : 1
        selectedIndex = (selectedIndex + delta + items.count) % items.count
        suppressHoverSelection = true
        floatingWindow.update(
            items: items,
            selectedIndex: selectedIndex,
            onHoverIndex: { [weak self] index in
                self?.selectByHover(index: index)
            },
            onActivateIndex: { [weak self] index in
                self?.activateByClick(index: index)
            }
        )
        installMouseMoveMonitorIfNeeded()
    }

    private func commitSelection() {
        removeMouseMoveMonitor()
        defer {
            items = []
            selectedIndex = 0
            floatingWindow.hide()
            SettingsWindowController.shared.finishSwitcherInteraction(didActivateOtherApp: true)
        }

        guard items.indices.contains(selectedIndex) else { return }
        windowService.activate(app: items[selectedIndex])
    }

    private func cancel() {
        removeMouseMoveMonitor()
        items = []
        selectedIndex = 0
        floatingWindow.hide()
        SettingsWindowController.shared.finishSwitcherInteraction(didActivateOtherApp: false)
    }

    private func stabilizedCycleItems(from fetchedItems: [SwitcherApp]) -> [SwitcherApp] {
        let currentPIDs = fetchedItems.map(\.pid)
        let retainedOrder = cycleOrder.filter { currentPIDs.contains($0) }
        let appendedOrder = retainedOrder + currentPIDs.filter { !retainedOrder.contains($0) }
        cycleOrder = appendedOrder

        let positions = Dictionary(uniqueKeysWithValues: appendedOrder.enumerated().map { ($0.element, $0.offset) })
        return fetchedItems.sorted {
            (positions[$0.pid] ?? .max) < (positions[$1.pid] ?? .max)
        }
    }

    private func nextSelectionIndex(in items: [SwitcherApp], reverse: Bool) -> Int {
        guard !items.isEmpty else { return 0 }
        guard let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let currentIndex = items.firstIndex(where: { $0.pid == frontmostPID }) else {
            return reverse ? max(items.count - 1, 0) : min(1, max(items.count - 1, 0))
        }

        let delta = reverse ? -1 : 1
        return (currentIndex + delta + items.count) % items.count
    }

    private func activeScreen() -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }

    private func selectByHover(index: Int) {
        guard !suppressHoverSelection else { return }
        guard items.indices.contains(index) else { return }
        guard selectedIndex != index else { return }
        selectedIndex = index
        floatingWindow.update(
            items: items,
            selectedIndex: selectedIndex,
            onHoverIndex: { [weak self] hoveredIndex in
                self?.selectByHover(index: hoveredIndex)
            },
            onActivateIndex: { [weak self] activatedIndex in
                self?.activateByClick(index: activatedIndex)
            }
        )
    }

    private func activateByClick(index: Int) {
        guard items.indices.contains(index) else { return }
        selectedIndex = index
        commitSelection()
    }

    private func installMouseMoveMonitorIfNeeded() {
        guard mouseMoveMonitor == nil else { return }
        mouseMoveMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            self?.suppressHoverSelection = false
            return event
        }
    }

    private func removeMouseMoveMonitor() {
        if let mouseMoveMonitor {
            NSEvent.removeMonitor(mouseMoveMonitor)
            self.mouseMoveMonitor = nil
        }
        suppressHoverSelection = false
    }
}
