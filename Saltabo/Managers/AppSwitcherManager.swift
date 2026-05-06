import AppKit
import ApplicationServices

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
    private var outsideClickMonitor: Any?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShortcutChange),
            name: .switcherShortcutDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSwitcherDisplayStyleChange),
            name: .switcherDisplayStyleDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSwitcherSizePresetChange),
            name: .switcherSizePresetDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSwitcherThemePresetChange),
            name: .switcherThemePresetDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSwitcherReleaseActionChange),
            name: .switcherReleaseActionDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSwitcherApplicationScopeChange),
            name: .switcherApplicationScopeDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSwitcherScreenScopeChange),
            name: .switcherScreenScopeDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSwitcherMinimizedWindowsVisibilityChange),
            name: .switcherMinimizedWindowsVisibilityDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSwitcherHiddenWindowsVisibilityChange),
            name: .switcherHiddenWindowsVisibilityDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSwitcherFullscreenWindowsVisibilityChange),
            name: .switcherFullscreenWindowsVisibilityDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSwitcherOrderPreferenceChange),
            name: .switcherOrderPreferenceDidChange,
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

    @objc private func handleSwitcherDisplayStyleChange() {
        guard !items.isEmpty else { return }
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
    }

    @objc private func handleSwitcherSizePresetChange() {
        guard !items.isEmpty else { return }
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
    }

    @objc private func handleSwitcherThemePresetChange() {
        guard !items.isEmpty else { return }
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
    }

    @objc private func handleSwitcherReleaseActionChange() {
        guard !items.isEmpty else { return }
        if AppSettings.shared.switcherReleaseAction == .keepOpen {
            installOutsideClickMonitorIfNeeded()
        } else {
            removeOutsideClickMonitor()
        }
    }

    @objc private func handleSwitcherApplicationScopeChange() {
        guard !items.isEmpty else { return }
        items = filteredItemsForCurrentSettings()
        guard !items.isEmpty else {
            cancel()
            return
        }
        selectedIndex = min(selectedIndex, max(0, items.count - 1))
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
    }

    @objc private func handleSwitcherScreenScopeChange() {
        guard !items.isEmpty else { return }
        items = filteredItemsForCurrentSettings()
        guard !items.isEmpty else {
            cancel()
            return
        }
        selectedIndex = min(selectedIndex, max(0, items.count - 1))
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
    }

    @objc private func handleSwitcherMinimizedWindowsVisibilityChange() {
        guard !items.isEmpty else { return }
        items = filteredItemsForCurrentSettings()
        guard !items.isEmpty else {
            cancel()
            return
        }
        selectedIndex = min(selectedIndex, max(0, items.count - 1))
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
    }

    @objc private func handleSwitcherHiddenWindowsVisibilityChange() {
        guard !items.isEmpty else { return }
        items = filteredItemsForCurrentSettings()
        guard !items.isEmpty else {
            cancel()
            return
        }
        selectedIndex = min(selectedIndex, max(0, items.count - 1))
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
    }

    @objc private func handleSwitcherFullscreenWindowsVisibilityChange() {
        guard !items.isEmpty else { return }
        items = filteredItemsForCurrentSettings()
        guard !items.isEmpty else {
            cancel()
            return
        }
        selectedIndex = min(selectedIndex, max(0, items.count - 1))
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
    }

    @objc private func handleSwitcherOrderPreferenceChange() {
        guard !items.isEmpty else { return }
        items = filteredItemsForCurrentSettings()
        guard !items.isEmpty else {
            cancel()
            return
        }
        selectedIndex = min(selectedIndex, max(0, items.count - 1))
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

        // Never hijack keyboard input while the Settings window is active.
        if SettingsWindowController.shared.window?.isKeyWindow == true {
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
                switch AppSettings.shared.switcherReleaseAction {
                case .focusSelectedWindow:
                    self.commitSelection()
                case .keepOpen:
                    self.suppressHoverSelection = false
                }
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
        let previouslySelectedPID =
            items.indices.contains(selectedIndex) ? items[selectedIndex].pid : nil
        let refreshedItems = filteredItemsForCurrentSettings()

        if items.isEmpty || explicitOpen {
            items = refreshedItems
            guard !items.isEmpty else { return }
            SettingsWindowController.shared.suppressForSwitcherIfVisible()
            if AppSettings.shared.switcherDisplayStyle == .thumbnails {
                ThumbnailCache.shared.warm(
                    items.flatMap(\.windows),
                    targetSize: FloatingSwitcherWindow.thumbnailCacheTargetSizeForCurrentPreset()
                )
            }
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
            installOutsideClickMonitorIfNeeded()
            return
        }

        items = refreshedItems
        guard !items.isEmpty else {
            cancel()
            return
        }

        if let previouslySelectedPID,
           let refreshedIndex = items.firstIndex(where: { $0.pid == previouslySelectedPID })
        {
            selectedIndex = refreshedIndex
        } else {
            selectedIndex = min(selectedIndex, max(0, items.count - 1))
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
        installOutsideClickMonitorIfNeeded()
    }

    private func commitSelection() {
        removeMouseMoveMonitor()
        removeOutsideClickMonitor()
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
        removeOutsideClickMonitor()
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

    private func filteredItemsForCurrentSettings() -> [SwitcherApp] {
        let fetchedSource: [SwitcherApp]
        switch AppSettings.shared.switcherScreenScope {
        case .currentScreenOnly:
            fetchedSource = windowService.currentSpaceApplications(on: activeScreen())
        case .allScreens:
            fetchedSource = windowService.allWindowsApplications()
        }
        let minimizedAugmented = includeMinimizedWindowsIfNeeded(base: fetchedSource)
        let minimizedFiltered = applyMinimizedWindowsVisibility(to: minimizedAugmented)
        let hiddenAugmented = includeHiddenWindowsIfNeeded(base: minimizedFiltered)
        let hiddenFiltered = applyHiddenWindowsVisibility(to: hiddenAugmented)
        let fullscreenFiltered = applyFullscreenWindowsVisibility(to: hiddenFiltered)
        let normalized = normalizeAppEntries(in: fullscreenFiltered)
        let ordered = orderItemsForCurrentSettings(from: normalized)
        let fetched = ordered
        guard let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            return fetched
        }
        switch AppSettings.shared.switcherApplicationScope {
        case .allApps:
            return fetched
        case .activeAppOnly:
            return fetched.filter { $0.pid == frontmostPID }
        case .nonActiveApps:
            return fetched.filter { $0.pid != frontmostPID }
        }
    }

    private func orderItemsForCurrentSettings(from items: [SwitcherApp]) -> [SwitcherApp] {
        switch AppSettings.shared.switcherOrderPreference {
        case .recentlyFocusedFirst:
            return stabilizedCycleItems(from: items)
        case .recentlyOpenedFirst:
            return items.sorted { lhs, rhs in
                let lhsDate = NSRunningApplication(processIdentifier: lhs.pid)?.launchDate ?? .distantPast
                let rhsDate = NSRunningApplication(processIdentifier: rhs.pid)?.launchDate ?? .distantPast
                return lhsDate > rhsDate
            }
        case .nameAZ:
            return items.sorted {
                $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
            }
        case .nameZA:
            return items.sorted {
                $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedDescending
            }
        }
    }

    private func normalizeAppEntries(in source: [SwitcherApp]) -> [SwitcherApp] {
        var seenPIDs = Set<pid_t>()
        var seenIdentity = Set<String>()
        var result: [SwitcherApp] = []
        result.reserveCapacity(source.count)

        for app in source {
            if seenPIDs.contains(app.pid) {
                continue
            }
            seenPIDs.insert(app.pid)

            let identity =
                (app.bundleIdentifier?.lowercased())
                ?? app.appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if seenIdentity.contains(identity) {
                continue
            }
            seenIdentity.insert(identity)
            result.append(app)
        }

        return result
    }

    private func includeMinimizedWindowsIfNeeded(base: [SwitcherApp]) -> [SwitcherApp] {
        guard AppSettings.shared.switcherMinimizedWindowsVisibility == .show else {
            return base
        }
        // `currentScreenOnly` is sourced from on-screen windows, which excludes minimized ones.
        // Add only minimized-only apps so we don't pull normal windows from other desktops.
        guard AppSettings.shared.switcherScreenScope == .currentScreenOnly else {
            return base
        }

        let visiblePIDs = Set(base.map(\.pid))
        var minimizedOnlyApps = windowService.allWindowsApplications().compactMap { app -> SwitcherApp? in
            guard !visiblePIDs.contains(app.pid) else { return nil }
            // Include only apps whose sampled windows are all minimized.
            let allMinimized = app.windows.allSatisfy { permissionService.isWindowMinimized(matching: $0) }
            guard allMinimized, let representative = app.windows.first else { return nil }
            return SwitcherApp(
                pid: app.pid,
                bundleIdentifier: app.bundleIdentifier,
                appName: app.appName,
                windows: [representative]
            )
        }

        let existingPIDs = Set(minimizedOnlyApps.map(\.pid)).union(visiblePIDs)
        let axFallbackApps = NSWorkspace.shared.runningApplications.compactMap { app -> SwitcherApp? in
            guard app.activationPolicy == .regular else { return nil }
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
            guard !existingPIDs.contains(app.processIdentifier) else { return nil }
            return minimizedAXRepresentativeApp(for: app)
        }
        minimizedOnlyApps.append(contentsOf: axFallbackApps)

        return base + minimizedOnlyApps
    }

    private func minimizedAXRepresentativeApp(for app: NSRunningApplication) -> SwitcherApp? {
        let axWindows = permissionService.windows(for: app.processIdentifier)
        guard !axWindows.isEmpty else { return nil }

        let minimizedWindows = axWindows.filter {
            permissionService.booleanValue(for: kAXMinimizedAttribute, on: $0) ?? false
        }
        // Only inject app if all known windows are minimized.
        guard !minimizedWindows.isEmpty, minimizedWindows.count == axWindows.count else { return nil }
        guard let representative = minimizedWindows.first else { return nil }

        let title = permissionService.stringValue(for: kAXTitleAttribute, on: representative) ?? ""
        let frame = permissionService.frame(for: representative) ?? CGRect(x: 0, y: 0, width: 900, height: 600)
        let window = WindowDescriptor(
            id: CGWindowID(UInt32(truncatingIfNeeded: app.processIdentifier)),
            pid: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            appName: app.localizedName ?? app.bundleIdentifier ?? "Application",
            title: title,
            bounds: frame,
            isOnScreen: false,
            windowLayer: 0,
            orderIndex: Int.max
        )
        return SwitcherApp(
            pid: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            appName: app.localizedName ?? app.bundleIdentifier ?? "Application",
            windows: [window]
        )
    }

    private func applyMinimizedWindowsVisibility(to source: [SwitcherApp]) -> [SwitcherApp] {
        guard AppSettings.shared.switcherMinimizedWindowsVisibility == .hide else {
            return source
        }
        return source.compactMap { app in
            let visibleWindows = app.windows.filter { window in
                !permissionService.isWindowMinimized(matching: window)
            }
            guard !visibleWindows.isEmpty else { return nil }
            return SwitcherApp(
                pid: app.pid,
                bundleIdentifier: app.bundleIdentifier,
                appName: app.appName,
                windows: visibleWindows
            )
        }
    }

    private func includeHiddenWindowsIfNeeded(base: [SwitcherApp]) -> [SwitcherApp] {
        guard AppSettings.shared.switcherHiddenWindowsVisibility == .show else {
            return base
        }

        let existingPIDs = Set(base.map(\.pid))
        let allWindowsApps = windowService.allWindowsApplications()
        let hiddenApps = NSWorkspace.shared.runningApplications.compactMap { app -> SwitcherApp? in
            guard app.activationPolicy == .regular else { return nil }
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
            guard app.isHidden else { return nil }
            guard !existingPIDs.contains(app.processIdentifier) else { return nil }

            if let representative = representativeWindowForApp(app, allWindowsApps: allWindowsApps) {
                return SwitcherApp(
                    pid: app.processIdentifier,
                    bundleIdentifier: app.bundleIdentifier,
                    appName: app.localizedName ?? app.bundleIdentifier ?? "Application",
                    windows: [representative]
                )
            }
            return nil
        }

        return base + hiddenApps
    }

    private func applyHiddenWindowsVisibility(to source: [SwitcherApp]) -> [SwitcherApp] {
        guard AppSettings.shared.switcherHiddenWindowsVisibility == .hide else {
            return source
        }
        return source.filter { app in
            !(NSRunningApplication(processIdentifier: app.pid)?.isHidden ?? false)
        }
    }

    private func applyFullscreenWindowsVisibility(to source: [SwitcherApp]) -> [SwitcherApp] {
        guard AppSettings.shared.switcherFullscreenWindowsVisibility == .hide else {
            return source
        }
        return source.compactMap { app in
            if appHasOnlyFullscreenAXWindows(pid: app.pid) {
                return nil
            }
            let fullscreenFrames = permissionService.fullscreenWindowFrames(for: app.pid)
            let visibleWindows = app.windows.filter { window in
                // Filter fullscreen windows at the window level so mixed-mode apps
                // still appear when they also have non-fullscreen windows.
                !isWindowFullscreenForFiltering(window, fullscreenFrames: fullscreenFrames)
            }
            guard !visibleWindows.isEmpty else { return nil }
            let removedFullscreenWindowCount = app.windows.count - visibleWindows.count
            let onlyOffscreenUtilityWindowsRemain =
                removedFullscreenWindowCount > 0
                && visibleWindows.allSatisfy { window in
                    !window.isOnScreen
                        && window.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            if onlyOffscreenUtilityWindowsRemain {
                return nil
            }
            let hadOnScreenWindow = app.windows.contains { $0.isOnScreen }
            let hasOnScreenNonFullscreenWindow = visibleWindows.contains { $0.isOnScreen }
            guard !hadOnScreenWindow || hasOnScreenNonFullscreenWindow else { return nil }
            return SwitcherApp(
                pid: app.pid,
                bundleIdentifier: app.bundleIdentifier,
                appName: app.appName,
                windows: visibleWindows
            )
        }
    }

    private func appHasOnlyFullscreenAXWindows(pid: pid_t) -> Bool {
        let axWindows = permissionService.windows(for: pid)
        guard !axWindows.isEmpty else { return false }

        var foundFullscreen = false

        for window in axWindows {
            let isMinimized = permissionService.booleanValue(for: kAXMinimizedAttribute, on: window) ?? false
            if isMinimized {
                continue
            }

            let isFullscreen = permissionService.booleanValue(for: "AXFullScreen", on: window) ?? false
            if !isFullscreen && isSubstantialNonFullscreenAXWindow(window) {
                return false
            }
            if isFullscreen {
                foundFullscreen = true
            }
        }

        return foundFullscreen
    }

    private func isSubstantialNonFullscreenAXWindow(_ window: AXUIElement) -> Bool {
        let title = permissionService.stringValue(for: kAXTitleAttribute, on: window)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let frame = permissionService.frame(for: window) ?? .zero

        if frame.width >= 800, frame.height >= 500 {
            return true
        }

        if !title.isEmpty && frame.width >= 300, frame.height >= 180 {
            return true
        }

        return false
    }

    private func isWindowFullscreenForFiltering(
        _ window: WindowDescriptor,
        fullscreenFrames: [CGRect]
    ) -> Bool {
        if fullscreenFrames.contains(where: { overlapRatio(between: $0, and: window.bounds) >= 0.55 }) {
            return true
        }
        if permissionService.isWindowFullscreen(matching: window) {
            return true
        }
        // Last-resort fallback only for exact screen-sized windows. This avoids
        // treating regular maximized windows as fullscreen in most cases.
        return isLikelyFullscreenByBounds(window.bounds)
    }

    private func isLikelyFullscreenByBounds(_ bounds: CGRect) -> Bool {
        let tolerance: CGFloat = 6
        let titlebarOverflowTolerance: CGFloat = 40
        for screen in NSScreen.screens {
            let frame = screen.frame
            let sameOrigin =
                abs(bounds.minX - frame.minX) <= tolerance
                && abs(bounds.minY - frame.minY) <= tolerance
            let sameSize =
                abs(bounds.width - frame.width) <= tolerance
                && abs(bounds.height - frame.height) <= tolerance
            let sameHorizontalBounds =
                abs(bounds.minX - frame.minX) <= tolerance
                && abs(bounds.width - frame.width) <= tolerance
            let sameVerticalSize = abs(bounds.height - frame.height) <= tolerance
            let titlebarAdjustedOrigin =
                bounds.minY <= frame.minY
                && (frame.minY - bounds.minY) <= titlebarOverflowTolerance
            if (sameOrigin && sameSize)
                || (sameHorizontalBounds && sameVerticalSize && titlebarAdjustedOrigin)
            {
                return true
            }
        }
        return false
    }

    private func overlapRatio(between lhs: CGRect, and rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        let overlap = intersection.width * intersection.height
        let base = max(lhs.width * lhs.height, rhs.width * rhs.height, 1)
        return overlap / base
    }

    private func representativeWindowForApp(
        _ app: NSRunningApplication,
        allWindowsApps: [SwitcherApp]
    ) -> WindowDescriptor? {
        if let fromCG = allWindowsApps.first(where: { $0.pid == app.processIdentifier })?
            .windows.first
        {
            return fromCG
        }
        guard let axWindow = permissionService.windows(for: app.processIdentifier).first else {
            return nil
        }
        let title = permissionService.stringValue(for: kAXTitleAttribute, on: axWindow) ?? ""
        let frame = permissionService.frame(for: axWindow) ?? CGRect(x: 0, y: 0, width: 900, height: 600)
        return WindowDescriptor(
            id: CGWindowID(UInt32(truncatingIfNeeded: app.processIdentifier)),
            pid: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            appName: app.localizedName ?? app.bundleIdentifier ?? "Application",
            title: title,
            bounds: frame,
            isOnScreen: false,
            windowLayer: 0,
            orderIndex: Int.max
        )
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

    private func installOutsideClickMonitorIfNeeded() {
        guard AppSettings.shared.switcherReleaseAction == .keepOpen else {
            removeOutsideClickMonitor()
            return
        }
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            guard let self else { return }
            let point = NSEvent.mouseLocation
            guard !self.floatingWindow.contains(screenPoint: point) else { return }
            DispatchQueue.main.async {
                guard !self.items.isEmpty else { return }
                self.cancel()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }
}
