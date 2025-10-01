import AppKit
import SwiftMailCore

/// コピー&ペースト可能なセキュアテキストフィールド
final class CopyableSecureTextField: NSSecureTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Cmd+C (Copy), Cmd+V (Paste), Cmd+X (Cut) を許可
        if event.modifierFlags.contains(.command) {
            if let characters = event.charactersIgnoringModifiers {
                if characters == "c" || characters == "v" || characters == "x" || characters == "a" {
                    return super.performKeyEquivalent(with: event)
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        // コピー、ペースト、カットメニューを有効化
        if let action = item.action {
            if action == #selector(NSText.copy(_:)) ||
               action == #selector(NSText.paste(_:)) ||
               action == #selector(NSText.cut(_:)) ||
               action == #selector(NSText.selectAll(_:)) {
                return true
            }
        }
        return super.validateUserInterfaceItem(item)
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            // 日本語入力を無効化（英数字入力のみ）
            NSTextInputContext.current?.discardMarkedText()
        }
        return result
    }
}

@MainActor
final class AccountSettingsViewController: NSViewController {

    // MARK: - UI Components

    private lazy var accountNameLabel = Self.createLabel("アカウント名:")
    private lazy var emailLabel = Self.createLabel("メールアドレス:")
    private lazy var imapHostLabel = Self.createLabel("IMAPサーバー:")
    private lazy var imapPortLabel = Self.createLabel("IMAPポート:")
    private lazy var smtpHostLabel = Self.createLabel("SMTPサーバー:")
    private lazy var smtpPortLabel = Self.createLabel("SMTPポート:")
    private lazy var usernameLabel = Self.createLabel("ユーザー名:")
    private lazy var passwordLabel = Self.createLabel("パスワード:")

    private let accountNameField: NSTextField = {
        let field = NSTextField()
        field.placeholderString = "例: 仕事用メール"
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let emailField: NSTextField = {
        let field = ASCIIOnlyTextField()
        field.placeholderString = "user@example.com"
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let imapHostField: NSTextField = {
        let field = ASCIIOnlyTextField()
        field.placeholderString = "imap.example.com"
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let imapPortField: NSTextField = {
        let field = ASCIIOnlyTextField()
        field.placeholderString = "993"
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let smtpHostField: NSTextField = {
        let field = ASCIIOnlyTextField()
        field.placeholderString = "smtp.example.com"
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let smtpPortField: NSTextField = {
        let field = ASCIIOnlyTextField()
        field.placeholderString = "587"
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let usernameField: NSTextField = {
        let field = ASCIIOnlyTextField()
        field.placeholderString = "user@example.com"
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let passwordField: NSSecureTextField = {
        let field = CopyableSecureTextField()
        field.placeholderString = "パスワード"
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let imapTLSCheckbox: NSButton = {
        let button = NSButton(checkboxWithTitle: "TLS/SSL使用", target: nil, action: nil)
        button.state = .on
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let smtpTLSCheckbox: NSButton = {
        let button = NSButton(checkboxWithTitle: "TLS/SSL使用", target: nil, action: nil)
        button.state = .on
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var saveButton: NSButton = {
        let button = NSButton(title: "保存", target: self, action: #selector(saveButtonTapped))
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var cancelButton: NSButton = {
        let button = NSButton(title: "キャンセル", target: self, action: #selector(cancelButtonTapped))
        button.bezelStyle = .rounded
        button.keyEquivalent = "\u{1b}"
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var testButton: NSButton = {
        let button = NSButton(title: "接続テスト", target: self, action: #selector(testConnectionTapped))
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Properties

    private let keychainManager = KeychainManager()
    var onSave: ((Account) -> Void)?
    var onCancel: (() -> Void)?
    private var editingAccount: Account?

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureLayout()
        populateDefaultValues()
    }

    // MARK: - Configuration

    private func configureLayout() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // IMAP Section
        let imapLabel = Self.createSectionLabel("IMAP設定（受信）")
        contentView.addSubview(imapLabel)
        contentView.addSubview(imapHostLabel)
        contentView.addSubview(imapHostField)
        contentView.addSubview(imapPortLabel)
        contentView.addSubview(imapPortField)
        contentView.addSubview(imapTLSCheckbox)

        // SMTP Section
        let smtpLabel = Self.createSectionLabel("SMTP設定（送信）")
        contentView.addSubview(smtpLabel)
        contentView.addSubview(smtpHostLabel)
        contentView.addSubview(smtpHostField)
        contentView.addSubview(smtpPortLabel)
        contentView.addSubview(smtpPortField)
        contentView.addSubview(smtpTLSCheckbox)

        // Account Info Section
        let accountLabel = Self.createSectionLabel("アカウント情報")
        contentView.addSubview(accountLabel)
        contentView.addSubview(accountNameLabel)
        contentView.addSubview(accountNameField)
        contentView.addSubview(emailLabel)
        contentView.addSubview(emailField)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(usernameField)
        contentView.addSubview(passwordLabel)
        contentView.addSubview(passwordField)

        // Buttons
        let buttonStack = NSStackView(views: [testButton, cancelButton, saveButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)

        scrollView.documentView = contentView
        view.addSubview(scrollView)

        let labelWidth: CGFloat = 120
        let fieldLeading: CGFloat = 140
        let margin: CGFloat = 16

        var currentY: CGFloat = margin

        // Account Info
        NSLayoutConstraint.activate([
            accountLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            accountLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            accountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin)
        ])
        currentY += 30

        NSLayoutConstraint.activate([
            accountNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            accountNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            accountNameLabel.widthAnchor.constraint(equalToConstant: labelWidth),

            accountNameField.centerYAnchor.constraint(equalTo: accountNameLabel.centerYAnchor),
            accountNameField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: fieldLeading),
            accountNameField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin)
        ])
        currentY += 32

        NSLayoutConstraint.activate([
            emailLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            emailLabel.leadingAnchor.constraint(equalTo: accountNameLabel.leadingAnchor),
            emailLabel.widthAnchor.constraint(equalTo: accountNameLabel.widthAnchor),

            emailField.centerYAnchor.constraint(equalTo: emailLabel.centerYAnchor),
            emailField.leadingAnchor.constraint(equalTo: accountNameField.leadingAnchor),
            emailField.trailingAnchor.constraint(equalTo: accountNameField.trailingAnchor)
        ])
        currentY += 32

        NSLayoutConstraint.activate([
            usernameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            usernameLabel.leadingAnchor.constraint(equalTo: accountNameLabel.leadingAnchor),
            usernameLabel.widthAnchor.constraint(equalTo: accountNameLabel.widthAnchor),

            usernameField.centerYAnchor.constraint(equalTo: usernameLabel.centerYAnchor),
            usernameField.leadingAnchor.constraint(equalTo: accountNameField.leadingAnchor),
            usernameField.trailingAnchor.constraint(equalTo: accountNameField.trailingAnchor)
        ])
        currentY += 32

        NSLayoutConstraint.activate([
            passwordLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            passwordLabel.leadingAnchor.constraint(equalTo: accountNameLabel.leadingAnchor),
            passwordLabel.widthAnchor.constraint(equalTo: accountNameLabel.widthAnchor),

            passwordField.centerYAnchor.constraint(equalTo: passwordLabel.centerYAnchor),
            passwordField.leadingAnchor.constraint(equalTo: accountNameField.leadingAnchor),
            passwordField.trailingAnchor.constraint(equalTo: accountNameField.trailingAnchor)
        ])
        currentY += 44

        // IMAP Section
        NSLayoutConstraint.activate([
            imapLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            imapLabel.leadingAnchor.constraint(equalTo: accountLabel.leadingAnchor),
            imapLabel.trailingAnchor.constraint(equalTo: accountLabel.trailingAnchor)
        ])
        currentY += 30

        NSLayoutConstraint.activate([
            imapHostLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            imapHostLabel.leadingAnchor.constraint(equalTo: accountNameLabel.leadingAnchor),
            imapHostLabel.widthAnchor.constraint(equalTo: accountNameLabel.widthAnchor),

            imapHostField.centerYAnchor.constraint(equalTo: imapHostLabel.centerYAnchor),
            imapHostField.leadingAnchor.constraint(equalTo: accountNameField.leadingAnchor),
            imapHostField.trailingAnchor.constraint(equalTo: accountNameField.trailingAnchor)
        ])
        currentY += 32

        NSLayoutConstraint.activate([
            imapPortLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            imapPortLabel.leadingAnchor.constraint(equalTo: accountNameLabel.leadingAnchor),
            imapPortLabel.widthAnchor.constraint(equalTo: accountNameLabel.widthAnchor),

            imapPortField.centerYAnchor.constraint(equalTo: imapPortLabel.centerYAnchor),
            imapPortField.leadingAnchor.constraint(equalTo: accountNameField.leadingAnchor),
            imapPortField.widthAnchor.constraint(equalToConstant: 100),

            imapTLSCheckbox.centerYAnchor.constraint(equalTo: imapPortLabel.centerYAnchor),
            imapTLSCheckbox.leadingAnchor.constraint(equalTo: imapPortField.trailingAnchor, constant: 16)
        ])
        currentY += 44

        // SMTP Section
        NSLayoutConstraint.activate([
            smtpLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            smtpLabel.leadingAnchor.constraint(equalTo: accountLabel.leadingAnchor),
            smtpLabel.trailingAnchor.constraint(equalTo: accountLabel.trailingAnchor)
        ])
        currentY += 30

        NSLayoutConstraint.activate([
            smtpHostLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            smtpHostLabel.leadingAnchor.constraint(equalTo: accountNameLabel.leadingAnchor),
            smtpHostLabel.widthAnchor.constraint(equalTo: accountNameLabel.widthAnchor),

            smtpHostField.centerYAnchor.constraint(equalTo: smtpHostLabel.centerYAnchor),
            smtpHostField.leadingAnchor.constraint(equalTo: accountNameField.leadingAnchor),
            smtpHostField.trailingAnchor.constraint(equalTo: accountNameField.trailingAnchor)
        ])
        currentY += 32

        NSLayoutConstraint.activate([
            smtpPortLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            smtpPortLabel.leadingAnchor.constraint(equalTo: accountNameLabel.leadingAnchor),
            smtpPortLabel.widthAnchor.constraint(equalTo: accountNameLabel.widthAnchor),

            smtpPortField.centerYAnchor.constraint(equalTo: smtpPortLabel.centerYAnchor),
            smtpPortField.leadingAnchor.constraint(equalTo: accountNameField.leadingAnchor),
            smtpPortField.widthAnchor.constraint(equalToConstant: 100),

            smtpTLSCheckbox.centerYAnchor.constraint(equalTo: smtpPortLabel.centerYAnchor),
            smtpTLSCheckbox.leadingAnchor.constraint(equalTo: smtpPortField.trailingAnchor, constant: 16)
        ])
        currentY += 44

        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            contentView.heightAnchor.constraint(equalToConstant: currentY),

            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -margin),

            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            buttonStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -margin)
        ])
    }

    private static func createLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private static func createSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func populateDefaultValues() {
        imapPortField.stringValue = "993"
        smtpPortField.stringValue = "587"
    }

    // MARK: - Actions

    @objc private func saveButtonTapped() {
        guard let account = validateAndCreateAccount() else {
            return
        }

        // パスワードをKeychainに保存
        do {
            try keychainManager.savePassword(passwordField.stringValue, for: account.id)
        } catch {
            showAlert(title: "エラー", message: "パスワードの保存に失敗しました: \(error.localizedDescription)")
            return
        }

        onSave?(account)
        // onSaveコールバック内でウィンドウが閉じられるため、ここでは閉じない
    }

    @objc private func cancelButtonTapped() {
        onCancel?()
        // onCancelコールバック内でウィンドウが閉じられるため、ここでは閉じない
    }

    @objc private func testConnectionTapped() {
        // TODO: 接続テスト実装
        showAlert(title: "接続テスト", message: "接続テスト機能は実装予定です")
    }

    // MARK: - Helpers

    private func validateAndCreateAccount() -> Account? {
        guard !emailField.stringValue.isEmpty else {
            showAlert(title: "入力エラー", message: "メールアドレスを入力してください")
            return nil
        }

        guard !imapHostField.stringValue.isEmpty else {
            showAlert(title: "入力エラー", message: "IMAPサーバーを入力してください")
            return nil
        }

        guard !smtpHostField.stringValue.isEmpty else {
            showAlert(title: "入力エラー", message: "SMTPサーバーを入力してください")
            return nil
        }

        guard let imapPort = Int(imapPortField.stringValue), imapPort > 0, imapPort < 65536 else {
            showAlert(title: "入力エラー", message: "有効なIMAPポート番号を入力してください")
            return nil
        }

        guard let smtpPort = Int(smtpPortField.stringValue), smtpPort > 0, smtpPort < 65536 else {
            showAlert(title: "入力エラー", message: "有効なSMTPポート番号を入力してください")
            return nil
        }

        let accountId = editingAccount?.id ?? UUID().uuidString

        return Account(
            id: accountId,
            email: emailField.stringValue,
            serverType: .imap,
            imapHost: imapHostField.stringValue,
            imapPort: imapPort,
            smtpHost: smtpHostField.stringValue,
            smtpPort: smtpPort
        )
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

    func setAccount(_ account: Account) {
        editingAccount = account
        accountNameField.stringValue = account.email
        emailField.stringValue = account.email
        imapHostField.stringValue = account.imapHost ?? ""
        imapPortField.stringValue = "\(account.imapPort)"
        imapTLSCheckbox.state = .on
        smtpHostField.stringValue = account.smtpHost
        smtpPortField.stringValue = "\(account.smtpPort)"
        smtpTLSCheckbox.state = .on
        usernameField.stringValue = account.email

        // パスワードをKeychainから取得
        if let password = try? keychainManager.retrievePassword(for: account.id) {
            passwordField.stringValue = password
        }
    }
}
