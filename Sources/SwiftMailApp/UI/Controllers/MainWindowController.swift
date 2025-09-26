import AppKit

@MainActor
final class MainWindowController: NSWindowController {
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SwiftMail"
        window.center()
        super.init(window: window)
        window.contentViewController = MainSplitViewController(environment: environment)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
