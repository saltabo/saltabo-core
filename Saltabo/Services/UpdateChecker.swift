import AppKit
import Foundation

final class UpdateChecker: NSObject {
    static let shared = UpdateChecker()

    private var periodicTimer: Timer?
    private let defaults = UserDefaults.standard
    private let lastAutomaticCheckDateKey = "Saltabo.lastAutomaticUpdateCheckDate"

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUpdatePolicyChange),
            name: .updateCheckPolicyDidChange,
            object: nil
        )
    }

    func startAutomaticChecksIfNeeded() {
        DispatchQueue.main.async {
            self.rescheduleAutomaticChecks()
        }
    }

    func stopAutomaticChecks() {
        periodicTimer?.invalidate()
        periodicTimer = nil
    }

    func checkForUpdates() {
        checkForUpdates(interactive: true, markAutomaticRun: false)
    }

    @objc private func handleUpdatePolicyChange() {
        DispatchQueue.main.async {
            self.rescheduleAutomaticChecks()
        }
    }

    private func rescheduleAutomaticChecks() {
        periodicTimer?.invalidate()
        periodicTimer = nil
        guard AppSettings.shared.updateCheckPolicy == .periodically else { return }

        runAutomaticCheckIfDue()

        periodicTimer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) {
            [weak self] _ in
            self?.runAutomaticCheckIfDue()
        }
    }

    private func runAutomaticCheckIfDue() {
        let now = Date()
        if let lastCheck = defaults.object(forKey: lastAutomaticCheckDateKey) as? Date,
           now.timeIntervalSince(lastCheck) < 24 * 60 * 60
        {
            return
        }
        checkForUpdates(interactive: false, markAutomaticRun: true)
    }

    private func checkForUpdates(interactive: Bool, markAutomaticRun: Bool) {
        guard let feedURLString = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let feedURL = URL(string: feedURLString) else {
            if interactive {
                presentAlert(
                    title: "Update feed is not configured",
                    message: "Add SUFeedURL to Info.plist to enable update checks."
                )
            }
            return
        }

        let task = URLSession.shared.dataTask(with: feedURL) { [weak self] data, _, error in
            guard let self else { return }

            if let error {
                if interactive {
                    self.presentAlert(
                        title: "Unable to check for updates",
                        message: error.localizedDescription
                    )
                }
                return
            }

            guard let data else {
                if interactive {
                    self.presentAlert(
                        title: "Unable to check for updates",
                        message: "No response data was received from the update feed."
                    )
                }
                return
            }

            guard let latestVersion = AppcastParser.parseLatestVersion(from: data) else {
                if interactive {
                    self.presentAlert(
                        title: "Unable to check for updates",
                        message: "Could not parse version information from the update feed."
                    )
                }
                return
            }

            if markAutomaticRun {
                self.defaults.set(Date(), forKey: self.lastAutomaticCheckDateKey)
            }

            let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                as? String ?? "0"

            if Self.isVersion(latestVersion, greaterThan: currentVersion) {
                self.presentUpdateAvailableAlert(version: latestVersion)
            } else if interactive {
                self.presentAlert(
                    title: "You're up to date",
                    message: "Saltabo \(currentVersion) is the latest version."
                )
            }
        }
        task.resume()
    }

    private static func isVersion(_ lhs: String, greaterThan rhs: String) -> Bool {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(left.count, right.count)

        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r {
                return l > r
            }
        }
        return false
    }

    private func presentUpdateAvailableAlert(version: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "Update available"
            alert.informativeText = "A newer version (\(version)) is available."
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    private func presentAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}

private final class AppcastParser: NSObject, XMLParserDelegate {
    private var isInsideItem = false
    private var latestVersion: String?
    private var captureBuffer = ""

    static func parseLatestVersion(from data: Data) -> String? {
        let parserDelegate = AppcastParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        guard parser.parse() else { return nil }
        return parserDelegate.latestVersion
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        captureBuffer = ""
        let resolvedName = qName ?? elementName

        if resolvedName == "item" {
            isInsideItem = true
        }

        guard isInsideItem, resolvedName == "enclosure" else { return }
        if latestVersion == nil {
            latestVersion =
                attributeDict["sparkle:shortVersionString"]
                ?? attributeDict["sparkle:version"]
                ?? attributeDict["shortVersionString"]
                ?? attributeDict["version"]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        captureBuffer.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let resolvedName = qName ?? elementName

        if isInsideItem, latestVersion == nil,
            (resolvedName == "sparkle:shortVersionString" || resolvedName == "shortVersionString")
        {
            let value = captureBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                latestVersion = value
            }
        }

        if resolvedName == "item" {
            isInsideItem = false
        }

        captureBuffer = ""
    }
}
