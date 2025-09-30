import AppKit
#if TARGET_INTERFACE_BUILDER

@MainActor
final class MessageDetailViewController: NSViewController {}

#else

import SwiftMailCore

@MainActor
final class MessageDetailViewController: NSViewController {
    @IBOutlet private weak var placeholderLabel: NSTextField!
    @IBOutlet private weak var subjectLabel: NSTextField!
    @IBOutlet private weak var metadataLabel: NSTextField!
    @IBOutlet private weak var bodyScrollView: NSScrollView!
    @IBOutlet private weak var bodyTextView: NSTextView!
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        updateUI(with: nil)
    }

    func display(message: Message?) {
        updateUI(with: message)
    }

    private func configureView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        bodyTextView.isEditable = false
        bodyTextView.drawsBackground = false
        bodyTextView.textContainerInset = NSSize(width: 0, height: 8)
        bodyTextView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        bodyScrollView.hasVerticalScroller = true
        bodyScrollView.drawsBackground = false
        subjectLabel.lineBreakMode = .byWordWrapping
        metadataLabel.lineBreakMode = .byWordWrapping
        placeholderLabel.lineBreakMode = .byWordWrapping
    }

    private func updateUI(with message: Message?) {
        guard let message else {
            placeholderLabel.isHidden = false
            subjectLabel.isHidden = true
            metadataLabel.isHidden = true
            bodyScrollView.isHidden = true
            bodyTextView.string = ""
            return
        }

        placeholderLabel.isHidden = true
        subjectLabel.isHidden = false
        metadataLabel.isHidden = false
        bodyScrollView.isHidden = false

        subjectLabel.stringValue = message.subject ?? "(件名なし)"

        let senderText: String
        if let sender = message.sender {
            senderText = sender.name?.isEmpty == false ? "差出人: \(sender.name!) <\(sender.email)>" : "差出人: \(sender.email)"
        } else {
            senderText = "差出人: 不明"
        }

        let dateText: String
        if let date = message.date {
            dateText = Self.dateFormatter.string(from: date)
        } else {
            dateText = ""
        }

        metadataLabel.stringValue = [senderText, dateText].filter { !$0.isEmpty }.joined(separator: "\n")
        bodyTextView.string = message.bodyPlain ?? "本文がありません"
    }
}

#endif
