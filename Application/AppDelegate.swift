import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let environment = AppEnvironment()
        environment.bootstrap()
        self.environment = environment
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment?.shutdown()
    }
}
