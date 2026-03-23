import AppKit

struct SwitcherApp: Identifiable, Hashable {
    let pid: pid_t
    let bundleIdentifier: String?
    let appName: String
    let windows: [WindowDescriptor]

    var id: pid_t { pid }
    var primaryWindow: WindowDescriptor { windows[0] }
    var icon: NSImage? { primaryWindow.icon }
    var subtitle: String {
        if windows.count > 1 {
            return "\(windows.count) windows"
        }
        return primaryWindow.title.isEmpty ? "Current Space" : primaryWindow.title
    }
}
