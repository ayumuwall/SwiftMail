import AppKit
#if TARGET_INTERFACE_BUILDER

@MainActor
final class MainWindowController: NSWindowController {
    var environment: AppEnvironment?
}

#else

@MainActor
final class MainWindowController: NSWindowController {
    var environment: AppEnvironment? {
        didSet { propagateEnvironment() }
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.title = "SwiftMail"
        window?.center()
        propagateEnvironment()
    }

    private func propagateEnvironment() {
        guard let environment, let splitController = contentViewController as? MainSplitViewController else {
            return
        }
        splitController.environment = environment
    }
}

#endif
