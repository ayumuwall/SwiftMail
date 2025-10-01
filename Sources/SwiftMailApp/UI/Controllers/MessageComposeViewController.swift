import AppKit
import SwiftMailCore

@MainActor
final class MessageComposeViewController: NSViewController {

    // MARK: - UI Components

    private let toTextField: NSTextField = {
        let field = ASCIIOnlyTextField()
        field.placeholderString = "宛先"
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let ccTextField: NSTextField = {
        let field = ASCIIOnlyTextField()
        field.placeholderString = "CC"
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let subjectTextField: NSTextField = {
        let field = NSTextField()
        field.placeholderString = "件名"
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let bodyTextView: NSTextView = {
        let textView = NSTextView()
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        return textView
    }()

    private let scrollView = NSScrollView()

    private lazy var sendButton: NSButton = {
        let button = NSButton(title: "送信", target: self, action: #selector(sendButtonTapped))
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r" // Enter key
        button.keyEquivalentModifierMask = .command // Cmd+Enter
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var cancelButton: NSButton = {
        let button = NSButton(title: "キャンセル", target: self, action: #selector(cancelButtonTapped))
        button.bezelStyle = .rounded
        button.keyEquivalent = "\u{1b}" // Escape key
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Properties

    var onSend: ((ComposedMessage) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureLayout()
    }

    // MARK: - Configuration

    private func configureLayout() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        // ScrollView設定
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = bodyTextView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        // ラベル
        let toLabel = createLabel("宛先:")
        let ccLabel = createLabel("CC:")
        let subjectLabel = createLabel("件名:")

        // ボタンコンテナ
        let buttonStack = NSStackView(views: [cancelButton, sendButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toLabel)
        view.addSubview(toTextField)
        view.addSubview(ccLabel)
        view.addSubview(ccTextField)
        view.addSubview(subjectLabel)
        view.addSubview(subjectTextField)
        view.addSubview(scrollView)
        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            // To
            toLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            toLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            toLabel.widthAnchor.constraint(equalToConstant: 60),

            toTextField.centerYAnchor.constraint(equalTo: toLabel.centerYAnchor),
            toTextField.leadingAnchor.constraint(equalTo: toLabel.trailingAnchor, constant: 8),
            toTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // CC
            ccLabel.topAnchor.constraint(equalTo: toLabel.bottomAnchor, constant: 12),
            ccLabel.leadingAnchor.constraint(equalTo: toLabel.leadingAnchor),
            ccLabel.widthAnchor.constraint(equalTo: toLabel.widthAnchor),

            ccTextField.centerYAnchor.constraint(equalTo: ccLabel.centerYAnchor),
            ccTextField.leadingAnchor.constraint(equalTo: toTextField.leadingAnchor),
            ccTextField.trailingAnchor.constraint(equalTo: toTextField.trailingAnchor),

            // Subject
            subjectLabel.topAnchor.constraint(equalTo: ccLabel.bottomAnchor, constant: 12),
            subjectLabel.leadingAnchor.constraint(equalTo: toLabel.leadingAnchor),
            subjectLabel.widthAnchor.constraint(equalTo: toLabel.widthAnchor),

            subjectTextField.centerYAnchor.constraint(equalTo: subjectLabel.centerYAnchor),
            subjectTextField.leadingAnchor.constraint(equalTo: toTextField.leadingAnchor),
            subjectTextField.trailingAnchor.constraint(equalTo: toTextField.trailingAnchor),

            // Body
            scrollView.topAnchor.constraint(equalTo: subjectLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -12),

            // Buttons
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            buttonStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
    }

    private func createLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    // MARK: - Actions

    @objc private func sendButtonTapped() {
        guard let from = getCurrentUserEmail() else {
            showAlert(title: "エラー", message: "送信元アドレスが設定されていません")
            return
        }

        let toAddresses = parseEmailAddresses(toTextField.stringValue)
        guard !toAddresses.isEmpty else {
            showAlert(title: "エラー", message: "宛先を入力してください")
            return
        }

        let ccAddresses = parseEmailAddresses(ccTextField.stringValue)
        let subject = subjectTextField.stringValue
        let body = bodyTextView.string

        let message = ComposedMessage(
            from: from,
            to: toAddresses,
            cc: ccAddresses,
            subject: subject,
            body: body
        )

        onSend?(message)
        view.window?.close()
    }

    @objc private func cancelButtonTapped() {
        onCancel?()
        view.window?.close()
    }

    // MARK: - Helpers

    private func parseEmailAddresses(_ text: String) -> [EmailAddress] {
        guard !text.isEmpty else { return [] }

        return text
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { EmailAddress(email: $0, name: nil) }
    }

    private func getCurrentUserEmail() -> EmailAddress? {
        // TODO: 実際のアカウント管理から取得
        // 現時点ではデモ用のダミー値を返す
        return EmailAddress(email: "user@example.com", name: "User")
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Public API

    func setReplyTo(originalMessage: Message) {
        // 返信先を設定
        if let sender = originalMessage.sender {
            toTextField.stringValue = sender.email
        }

        // 件名に "Re: " を追加
        if let subject = originalMessage.subject, !subject.hasPrefix("Re:") {
            subjectTextField.stringValue = "Re: \(subject)"
        } else {
            subjectTextField.stringValue = originalMessage.subject ?? ""
        }

        // 引用テキストを追加
        if let body = originalMessage.bodyPlain {
            bodyTextView.string = "\n\n> \(body.replacingOccurrences(of: "\n", with: "\n> "))"
        }
    }
}

// MARK: - Supporting Types

struct ComposedMessage {
    let from: EmailAddress
    let to: [EmailAddress]
    let cc: [EmailAddress]
    let subject: String
    let body: String
}
