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
    private lazy var serverTypeLabel = Self.createLabel("プロトコル:")
    private lazy var receiveHostLabel = Self.createLabel("受信サーバー:")
    private lazy var receivePortLabel = Self.createLabel("受信ポート:")
    private lazy var smtpHostLabel = Self.createLabel("送信サーバー:")
    private lazy var smtpPortLabel = Self.createLabel("送信ポート:")
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

    private lazy var serverTypePopUp: NSPopUpButton = {
        let button = NSPopUpButton()
        button.addItems(withTitles: ["IMAP", "POP3"])
        button.target = self
        button.action = #selector(serverTypeChanged)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var serverTypeHeaderLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let receiveHostField: NSTextField = {
        let field = ASCIIOnlyTextField()
        field.placeholderString = "imap.example.com"
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let receivePortField: NSTextField = {
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

    private let receiveTLSCheckbox: NSButton = {
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
    private var isEditMode = false

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
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        // Protocol Type Section (at the top of window, outside scroll view)
        let protocolHeaderView = NSView()
        protocolHeaderView.translatesAutoresizingMaskIntoConstraints = false
        protocolHeaderView.wantsLayer = true
        protocolHeaderView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        view.addSubview(protocolHeaderView)
        protocolHeaderView.addSubview(serverTypeLabel)
        protocolHeaderView.addSubview(serverTypePopUp)
        protocolHeaderView.addSubview(serverTypeHeaderLabel)

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

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

        // Receive Section
        let receiveLabel = Self.createSectionLabel("受信")
        contentView.addSubview(receiveLabel)
        contentView.addSubview(receiveHostLabel)
        contentView.addSubview(receiveHostField)
        contentView.addSubview(receivePortLabel)
        contentView.addSubview(receivePortField)
        contentView.addSubview(receiveTLSCheckbox)

        // Send Section
        let smtpLabel = Self.createSectionLabel("送信")
        contentView.addSubview(smtpLabel)
        contentView.addSubview(smtpHostLabel)
        contentView.addSubview(smtpHostField)
        contentView.addSubview(smtpPortLabel)
        contentView.addSubview(smtpPortField)
        contentView.addSubview(smtpTLSCheckbox)

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
        let fieldWidth: CGFloat = 280
        let margin: CGFloat = 20
        let protocolHeaderHeight: CGFloat = 40
        let bottomMargin: CGFloat = 12

        // Protocol Header Layout
        NSLayoutConstraint.activate([
            protocolHeaderView.topAnchor.constraint(equalTo: view.topAnchor),
            protocolHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            protocolHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            protocolHeaderView.heightAnchor.constraint(equalToConstant: protocolHeaderHeight),

            serverTypeLabel.centerYAnchor.constraint(equalTo: protocolHeaderView.centerYAnchor),
            serverTypeLabel.leadingAnchor.constraint(equalTo: protocolHeaderView.leadingAnchor, constant: margin),
            serverTypeLabel.widthAnchor.constraint(equalToConstant: labelWidth),

            serverTypePopUp.centerYAnchor.constraint(equalTo: protocolHeaderView.centerYAnchor),
            serverTypePopUp.leadingAnchor.constraint(equalTo: protocolHeaderView.leadingAnchor, constant: fieldLeading),
            serverTypePopUp.widthAnchor.constraint(equalToConstant: 150),

            serverTypeHeaderLabel.centerYAnchor.constraint(equalTo: protocolHeaderView.centerYAnchor),
            serverTypeHeaderLabel.leadingAnchor.constraint(equalTo: protocolHeaderView.leadingAnchor, constant: fieldLeading)
        ])

        var currentY: CGFloat = 8

        // Account Info
        NSLayoutConstraint.activate([
            accountLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            accountLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            accountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin)
        ])
        currentY += 26

        NSLayoutConstraint.activate([
            accountNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            accountNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            accountNameLabel.widthAnchor.constraint(equalToConstant: labelWidth),

            accountNameField.centerYAnchor.constraint(equalTo: accountNameLabel.centerYAnchor),
            accountNameField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: fieldLeading),
            accountNameField.widthAnchor.constraint(equalToConstant: fieldWidth)
        ])
        currentY += 28

        NSLayoutConstraint.activate([
            emailLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            emailLabel.leadingAnchor.constraint(equalTo: accountNameLabel.leadingAnchor),
            emailLabel.widthAnchor.constraint(equalTo: accountNameLabel.widthAnchor),

            emailField.centerYAnchor.constraint(equalTo: emailLabel.centerYAnchor),
            emailField.leadingAnchor.constraint(equalTo: accountNameField.leadingAnchor),
            emailField.widthAnchor.constraint(equalTo: accountNameField.widthAnchor)
        ])
        currentY += 28

        NSLayoutConstraint.activate([
            usernameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            usernameLabel.leadingAnchor.constraint(equalTo: accountNameLabel.leadingAnchor),
            usernameLabel.widthAnchor.constraint(equalTo: accountNameLabel.widthAnchor),

            usernameField.centerYAnchor.constraint(equalTo: usernameLabel.centerYAnchor),
            usernameField.leadingAnchor.constraint(equalTo: accountNameField.leadingAnchor),
            usernameField.widthAnchor.constraint(equalTo: accountNameField.widthAnchor)
        ])
        currentY += 28

        NSLayoutConstraint.activate([
            passwordLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            passwordLabel.leadingAnchor.constraint(equalTo: accountNameLabel.leadingAnchor),
            passwordLabel.widthAnchor.constraint(equalTo: accountNameLabel.widthAnchor),

            passwordField.centerYAnchor.constraint(equalTo: passwordLabel.centerYAnchor),
            passwordField.leadingAnchor.constraint(equalTo: accountNameField.leadingAnchor),
            passwordField.widthAnchor.constraint(equalTo: accountNameField.widthAnchor)
        ])
        currentY += 38

        // Receive Section
        NSLayoutConstraint.activate([
            receiveLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            receiveLabel.leadingAnchor.constraint(equalTo: accountLabel.leadingAnchor),
            receiveLabel.trailingAnchor.constraint(equalTo: accountLabel.trailingAnchor)
        ])
        currentY += 26

        NSLayoutConstraint.activate([
            receiveHostLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            receiveHostLabel.leadingAnchor.constraint(equalTo: accountNameLabel.leadingAnchor),
            receiveHostLabel.widthAnchor.constraint(equalTo: accountNameLabel.widthAnchor),

            receiveHostField.centerYAnchor.constraint(equalTo: receiveHostLabel.centerYAnchor),
            receiveHostField.leadingAnchor.constraint(equalTo: accountNameField.leadingAnchor),
            receiveHostField.widthAnchor.constraint(equalTo: accountNameField.widthAnchor)
        ])
        currentY += 28

        NSLayoutConstraint.activate([
            receivePortLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            receivePortLabel.leadingAnchor.constraint(equalTo: accountNameLabel.leadingAnchor),
            receivePortLabel.widthAnchor.constraint(equalTo: accountNameLabel.widthAnchor),

            receivePortField.centerYAnchor.constraint(equalTo: receivePortLabel.centerYAnchor),
            receivePortField.leadingAnchor.constraint(equalTo: accountNameField.leadingAnchor),
            receivePortField.widthAnchor.constraint(equalToConstant: 100),

            receiveTLSCheckbox.centerYAnchor.constraint(equalTo: receivePortLabel.centerYAnchor),
            receiveTLSCheckbox.leadingAnchor.constraint(equalTo: receivePortField.trailingAnchor, constant: 16)
        ])
        currentY += 38

        // Send Section
        NSLayoutConstraint.activate([
            smtpLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            smtpLabel.leadingAnchor.constraint(equalTo: accountLabel.leadingAnchor),
            smtpLabel.trailingAnchor.constraint(equalTo: accountLabel.trailingAnchor)
        ])
        currentY += 26

        NSLayoutConstraint.activate([
            smtpHostLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: currentY),
            smtpHostLabel.leadingAnchor.constraint(equalTo: accountNameLabel.leadingAnchor),
            smtpHostLabel.widthAnchor.constraint(equalTo: accountNameLabel.widthAnchor),

            smtpHostField.centerYAnchor.constraint(equalTo: smtpHostLabel.centerYAnchor),
            smtpHostField.leadingAnchor.constraint(equalTo: accountNameField.leadingAnchor),
            smtpHostField.widthAnchor.constraint(equalTo: accountNameField.widthAnchor)
        ])
        currentY += 28

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
        currentY += 32

        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            contentView.heightAnchor.constraint(equalToConstant: currentY),

            scrollView.topAnchor.constraint(equalTo: protocolHeaderView.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -8),

            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            buttonStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -bottomMargin)
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
        receivePortField.stringValue = "993"
        smtpPortField.stringValue = "587"
        updateServerTypeDisplay()
    }

    private func updateServerTypeDisplay() {
        if isEditMode {
            // 編集モード: PopUpを非表示、見出しを表示
            serverTypeLabel.isHidden = false
            serverTypePopUp.isHidden = true
            serverTypeHeaderLabel.isHidden = false

            let typeText = serverTypePopUp.indexOfSelectedItem == 0 ? "IMAPアカウント" : "POP3アカウント"
            serverTypeHeaderLabel.stringValue = typeText
        } else {
            // 新規作成モード: PopUpを表示、見出しを非表示
            serverTypeLabel.isHidden = false
            serverTypePopUp.isHidden = false
            serverTypeHeaderLabel.isHidden = true
        }
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

    @objc private func serverTypeChanged() {
        // プロトコル変更時の処理（必要に応じて実装）
    }

    // MARK: - Helpers

    private func validateAndCreateAccount() -> Account? {
        guard !emailField.stringValue.isEmpty else {
            showAlert(title: "入力エラー", message: "メールアドレスを入力してください")
            return nil
        }

        let selectedServerType: Account.ServerType = serverTypePopUp.indexOfSelectedItem == 0 ? .imap : .pop3

        guard !receiveHostField.stringValue.isEmpty else {
            showAlert(title: "入力エラー", message: "受信サーバーを入力してください")
            return nil
        }

        guard let receivePort = Int(receivePortField.stringValue), receivePort > 0, receivePort < 65536 else {
            showAlert(title: "入力エラー", message: "有効な受信ポート番号を入力してください")
            return nil
        }

        guard !smtpHostField.stringValue.isEmpty else {
            showAlert(title: "入力エラー", message: "送信サーバーを入力してください")
            return nil
        }

        guard let smtpPort = Int(smtpPortField.stringValue), smtpPort > 0, smtpPort < 65536 else {
            showAlert(title: "入力エラー", message: "有効な送信ポート番号を入力してください")
            return nil
        }

        let accountId = editingAccount?.id ?? UUID().uuidString

        return Account(
            id: accountId,
            email: emailField.stringValue,
            serverType: selectedServerType,
            imapHost: receiveHostField.stringValue,
            imapPort: receivePort,
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
        isEditMode = true

        accountNameField.stringValue = account.email
        emailField.stringValue = account.email
        receiveHostField.stringValue = account.imapHost ?? ""
        receivePortField.stringValue = "\(account.imapPort)"
        receiveTLSCheckbox.state = .on
        smtpHostField.stringValue = account.smtpHost
        smtpPortField.stringValue = "\(account.smtpPort)"
        smtpTLSCheckbox.state = .on
        usernameField.stringValue = account.email

        // サーバータイプを設定
        serverTypePopUp.selectItem(at: account.serverType == .imap ? 0 : 1)

        // パスワードをKeychainから取得
        if let password = try? keychainManager.retrievePassword(for: account.id) {
            passwordField.stringValue = password
        }

        // UI更新
        updateServerTypeDisplay()
    }
}
