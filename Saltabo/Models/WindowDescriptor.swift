import AppKit

struct WindowDescriptor: Identifiable, Hashable {
    let id: CGWindowID
    let pid: pid_t
    let bundleIdentifier: String?
    let appName: String
    let title: String
    let bounds: CGRect
    let windowLayer: Int
    let orderIndex: Int

    var displayTitle: String {
        title.isEmpty ? appName : title
    }

    var icon: NSImage? {
        NSRunningApplication(processIdentifier: pid)?.icon
    }
}
