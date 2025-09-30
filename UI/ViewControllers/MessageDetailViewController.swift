import AppKit

final class MessageDetailViewController: NSViewController {
    @IBOutlet private weak var textView: NSTextView?

    override func viewDidLoad() {
        super.viewDidLoad()
        if textView == nil {
            textView = locateTextView(in: view)
        }
        textView?.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView?.string = "メッセージを選択してください。"
    }

    func present(message: Message) {
        let header = "From: \(message.sender)\nSubject: \(message.subject)\nDate: \(message.dateFormatted)\n"
        textView?.string = header + "\n" + message.bodyPlain
    }

    private func locateTextView(in view: NSView) -> NSTextView? {
        if let textView = view as? NSTextView {
            return textView
        }
        for subview in view.subviews {
            if let textView = locateTextView(in: subview) {
                return textView
            }
        }
        return nil
    }
}
