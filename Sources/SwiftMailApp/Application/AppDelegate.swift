import AppKit
import SwiftMailCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?
    private var environment: AppEnvironment?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let environment = try AppEnvironment.bootstrap()
            self.environment = environment

            let windowController = MainWindowController(environment: environment)
            windowController.showWindow(self)
            self.windowController = windowController
        } catch {
            presentFatalError(error)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment?.database.close()
    }

    private func presentFatalError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "アプリケーションを初期化できません"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.addButton(withTitle: "終了")
        alert.runModal()
        NSApplication.shared.terminate(self)
    }
}
