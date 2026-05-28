import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        let mainBundleIdentifier = bundleIdentifier.replacingOccurrences(
            of: #"-LaunchAtLoginHelper$"#,
            with: "",
            options: .regularExpression
        )

        guard NSRunningApplication.runningApplications(withBundleIdentifier: mainBundleIdentifier).isEmpty else {
            NSApp.terminate(nil)
            return
        }

        let pathComponents = (Bundle.main.bundlePath as NSString).pathComponents
        let mainPath = NSString.path(withComponents: Array(pathComponents[0...(pathComponents.count - 5)]))
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: mainPath),
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, _ in
            NSApp.terminate(nil)
        }
    }
}

@main
enum FuwariHelperMain {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}
