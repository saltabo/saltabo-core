import AppKit

final class MoveToApplicationsManager {
    static let shared = MoveToApplicationsManager()

    private init() {}

    @discardableResult
    func promptIfNeeded() -> Bool {
        guard shouldPromptToMove else { return false }

        let wasAccessory = NSApp.activationPolicy() == .accessory
        if wasAccessory {
            NSApp.setActivationPolicy(.regular)
        }

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage
        alert.messageText = "Move to Applications folder?"
        alert.informativeText = "I can move myself to the Applications folder if you'd like."
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't ask again"
        alert.addButton(withTitle: "Move to Applications Folder")
        alert.addButton(withTitle: "Do Not Move")

        let response = alert.runModal()
        if alert.suppressionButton?.state == .on {
            AppSettings.shared.suppressMoveToApplicationsPrompt = true
        }

        if response == .alertFirstButtonReturn {
            moveAndRelaunch()
            return true
        }

        if wasAccessory, SettingsWindowController.shared.window?.isVisible != true {
            NSApp.setActivationPolicy(.accessory)
        }

        return false
    }

    private var shouldPromptToMove: Bool {
        guard !AppSettings.shared.suppressMoveToApplicationsPrompt else { return false }
        guard !isRunningFromApplicationsFolder else { return false }
        guard !isDevelopmentLaunch else { return false }
        return isQuarantined || isTranslocated || isRunningFromUserFacingLocation
    }

    private var isDevelopmentLaunch: Bool {
        let bundlePath = Bundle.main.bundleURL.path
        return bundlePath.contains("/DerivedData/")
            || bundlePath.contains("/Build/Products/")
            || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var isRunningFromApplicationsFolder: Bool {
        let bundleURL = Bundle.main.bundleURL
        let systemApplicationsURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let userApplicationsURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Applications", isDirectory: true)

        return bundleURL.isInDirectory(systemApplicationsURL)
            || bundleURL.isInDirectory(userApplicationsURL)
    }

    private var isTranslocated: Bool {
        Bundle.main.bundleURL.path.contains("/AppTranslocation/")
    }

    private var isRunningFromUserFacingLocation: Bool {
        let bundlePath = Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL.path
        let home = NSHomeDirectory()
        let candidatePrefixes = [
            home + "/Downloads/",
            home + "/Desktop/",
            home + "/Documents/"
        ]
        return candidatePrefixes.contains { bundlePath.hasPrefix($0) }
    }

    private var isQuarantined: Bool {
        extendedAttribute(named: "com.apple.quarantine", at: Bundle.main.bundleURL) != nil
    }

    private func moveAndRelaunch() {
        let currentBundleURL = Bundle.main.bundleURL
        let destinationURL = preferredDestinationURL()

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            relaunch(at: destinationURL)
            return
        }

        do {
            try FileManager.default.copyItem(at: currentBundleURL, to: destinationURL)
            relaunch(at: destinationURL)
        } catch {
            presentMoveError(error, destinationURL: destinationURL)
        }
    }

    private func preferredDestinationURL() -> URL {
        let appName = Bundle.main.bundleURL.lastPathComponent
        let systemApplications = URL(fileURLWithPath: "/Applications", isDirectory: true)
        if FileManager.default.isWritableFile(atPath: systemApplications.path) {
            return systemApplications.appendingPathComponent(appName, isDirectory: true)
        }

        let userApplications = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Applications", isDirectory: true)
        try? FileManager.default.createDirectory(at: userApplications, withIntermediateDirectories: true)
        return userApplications.appendingPathComponent(appName, isDirectory: true)
    }

    private func relaunch(at destinationURL: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: destinationURL, configuration: configuration) { _, _ in
            NSApp.terminate(nil)
        }
    }

    private func presentMoveError(_ error: Error, destinationURL: URL) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn't move Saltabo"
        alert.informativeText = """
            Saltabo couldn't move itself to:
            \(destinationURL.path)

            \(error.localizedDescription)
            """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func extendedAttribute(named name: String, at url: URL) -> Data? {
        let path = url.path
        let length = getxattr(path, name, nil, 0, 0, 0)
        guard length > 0 else { return nil }

        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { buffer in
            getxattr(path, name, buffer.baseAddress, length, 0, 0)
        }
        guard result == length else { return nil }
        return data
    }
}

private extension URL {
    func isInDirectory(_ directoryURL: URL) -> Bool {
        let canonicalPath = normalizedDataVolumePath(
            resolvingSymlinksInPath().standardizedFileURL.path)
        let canonicalDirectoryPath = normalizedDataVolumePath(
            directoryURL.resolvingSymlinksInPath().standardizedFileURL.path)
        return canonicalPath == canonicalDirectoryPath
            || canonicalPath.hasPrefix(canonicalDirectoryPath + "/")
    }

    private func normalizedDataVolumePath(_ path: String) -> String {
        let dataVolumePrefix = "/System/Volumes/Data"
        guard path.hasPrefix(dataVolumePrefix + "/") else { return path }
        return String(path.dropFirst(dataVolumePrefix.count))
    }
}
