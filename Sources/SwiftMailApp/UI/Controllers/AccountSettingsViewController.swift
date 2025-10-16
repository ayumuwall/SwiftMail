import AppKit
import SwiftMailCore

// MARK: - Timeout Helper

struct TimeoutError: Error, LocalizedError {
    var errorDescription: String? { "接続がタイムアウトしました" }
}

func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }

        guard let result = try await group.next() else {
            group.cancelAll()
            throw TimeoutError()
        }

        group.cancelAll()
        return result
    }
}

// MARK: - UI Components

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

    private var progressIndicator: NSProgressIndicator?
    private var progressLabel: NSTextField?

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
        if !isEditMode {
            receivePortField.stringValue = "993"
            smtpPortField.stringValue = "587"
        }
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
        Task { @MainActor in
            await performConnectionTest()
        }
    }

    @objc private func serverTypeChanged() {
        // プロトコル変更時の処理（必要に応じて実装）
    }

    // MARK: - Connection Test

    @MainActor
    private func performConnectionTest() async {
        // 入力値の検証
        guard !receiveHostField.stringValue.isEmpty else {
            showAlert(title: "入力エラー", message: "受信サーバーを入力してください")
            return
        }

        guard let receivePort = Int(receivePortField.stringValue), receivePort > 0, receivePort < 65536 else {
            showAlert(title: "入力エラー", message: "有効な受信ポート番号を入力してください")
            return
        }

        guard !smtpHostField.stringValue.isEmpty else {
            showAlert(title: "入力エラー", message: "送信サーバーを入力してください")
            return
        }

        guard let smtpPort = Int(smtpPortField.stringValue), smtpPort > 0, smtpPort < 65536 else {
            showAlert(title: "入力エラー", message: "有効な送信ポート番号を入力してください")
            return
        }

        let trimmedEmail = emailField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = usernameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let loginUsername = trimmedUsername.isEmpty ? trimmedEmail : trimmedUsername

        guard !loginUsername.isEmpty else {
            showAlert(title: "入力エラー", message: "ユーザー名を入力してください")
            return
        }

        let password = passwordField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !password.isEmpty else {
            showAlert(title: "入力エラー", message: "パスワードを入力してください")
            return
        }

        // プログレスインジケーターを表示
        showProgressIndicator()

        var receiveResult = ""
        var sendResult = ""

        // 受信サーバーテスト
        let serverTypeIndex = serverTypePopUp.indexOfSelectedItem
        let serverType = serverTypeIndex == 0 ? "IMAP" : "POP3"
        let tlsStatus = receiveTLSCheckbox.state == .on ? "TLS有効" : "TLS無効"
        var activeIMAPClient: IMAPClient?
        var activePOP3Client: POP3Client?

        updateProgress("""
        【受信サーバーテスト】
        プロトコル: \(serverType)
        ホスト: \(receiveHostField.stringValue)
        ポート: \(receivePort)
        セキュリティ: \(tlsStatus)

        接続中...
        """)

        do {
            if serverTypeIndex == 0 {
                let client = IMAPClient(
                    host: receiveHostField.stringValue,
                    port: receivePort,
                    useTLS: receiveTLSCheckbox.state == .on
                )
                activeIMAPClient = client
                try await withTimeout(seconds: 10) {
                    try await client.connect()
                    try await client.login(email: loginUsername, password: password)
                }
                client.disconnect()
                activeIMAPClient = nil
            } else {
                let client = POP3Client(
                    host: receiveHostField.stringValue,
                    port: receivePort,
                    useTLS: receiveTLSCheckbox.state == .on
                )
                activePOP3Client = client
                try await withTimeout(seconds: 10) {
                    try await client.connect()
                    try await client.login(username: loginUsername, password: password)
                }
                try await client.disconnect()
                activePOP3Client = nil
            }
            receiveResult = "✅ 受信サーバー (\(serverType)): 接続・認証成功"
        } catch is TimeoutError {
            activeIMAPClient?.disconnect()
            if let client = activePOP3Client {
                try? await client.disconnect()
            }
            receiveResult = "❌ 受信サーバー: 接続タイムアウト（10秒）"
        } catch {
            activeIMAPClient?.disconnect()
            if let client = activePOP3Client {
                try? await client.disconnect()
            }
            if let imapError = error as? IMAPClient.IMAPError {
                switch imapError {
                case .authenticationFailed:
                    receiveResult = "❌ 受信サーバー: 認証に失敗しました"
                default:
                    receiveResult = "❌ 受信サーバー: 接続失敗\n\(imapError.localizedDescription)"
                }
            } else if let pop3Error = error as? POP3Client.POP3Error {
                switch pop3Error {
                case .authenticationFailed:
                    receiveResult = "❌ 受信サーバー: 認証に失敗しました"
                default:
                    receiveResult = "❌ 受信サーバー: 接続失敗\n\(pop3Error.localizedDescription)"
                }
            } else {
                receiveResult = "❌ 受信サーバー: 接続失敗\n\(error.localizedDescription)"
            }
        }

        // 送信サーバーテスト
        var smtpClient: SMTPClient?
        do {
            let tlsStatus = smtpTLSCheckbox.state == .on ? "TLS有効" : "TLS無効"

            updateProgress("""
            【送信サーバーテスト】
            プロトコル: SMTP
            ホスト: \(smtpHostField.stringValue)
            ポート: \(smtpPort)
            セキュリティ: \(tlsStatus)

            接続中...
            """)

            let client = SMTPClient(
                host: smtpHostField.stringValue,
                port: smtpPort,
                useTLS: smtpTLSCheckbox.state == .on
            )
            smtpClient = client
            try await withTimeout(seconds: 10) {
                try await client.connect()
                try await client.ehlo()
                try await client.login(username: loginUsername, password: password)
            }
            try await client.disconnect()
            smtpClient = nil
            sendResult = "✅ 送信サーバー (SMTP): 接続・認証成功"
        } catch is TimeoutError {
            if let client = smtpClient {
                try? await client.disconnect()
                smtpClient = nil
            }
            sendResult = "❌ 送信サーバー: 接続タイムアウト（10秒）"
        } catch {
            if let client = smtpClient {
                try? await client.disconnect()
                smtpClient = nil
            }
            if let smtpError = error as? SMTPClient.SMTPError {
                switch smtpError {
                case .authenticationFailed:
                    sendResult = "❌ 送信サーバー: 認証に失敗しました"
                default:
                    sendResult = "❌ 送信サーバー: 接続失敗\n\(smtpError.localizedDescription)"
                }
            } else {
                sendResult = "❌ 送信サーバー: 接続失敗\n\(error.localizedDescription)"
            }
        }

        // プログレスインジケーターを非表示
        hideProgressIndicator()

        // 結果を表示
        let message = "\(receiveResult)\n\n\(sendResult)"
        showAlert(title: "接続テスト結果", message: message)
    }

    @MainActor
    private func showProgressIndicator() {
        // 背景オーバーレイ（ウィンドウ全体をホワイトアウト）
        let overlayView = NSView()
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.wantsLayer = true
        overlayView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.85).cgColor

        view.addSubview(overlayView)

        // プログレスインジケーターを作成
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimation(nil)

        let titleLabel = NSTextField(labelWithString: "接続テスト中...")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.alignment = .center

        let detailLabel = NSTextField(wrappingLabelWithString: "")
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.alignment = .center
        detailLabel.maximumNumberOfLines = 5
        detailLabel.preferredMaxLayoutWidth = 350

        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        containerView.layer?.cornerRadius = 12
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor

        // シャドウを追加
        containerView.shadow = NSShadow()
        containerView.layer?.shadowOpacity = 0.3
        containerView.layer?.shadowRadius = 10
        containerView.layer?.shadowOffset = NSSize(width: 0, height: -2)

        containerView.addSubview(indicator)
        containerView.addSubview(titleLabel)
        containerView.addSubview(detailLabel)

        overlayView.addSubview(containerView)

        NSLayoutConstraint.activate([
            // オーバーレイはビュー全体を覆う
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // コンテナを中央配置
            containerView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 400),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150),

            // スピナーを上部中央に配置
            indicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            indicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),

            // タイトルラベル
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: indicator.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            // 詳細ラベル
            detailLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            detailLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            detailLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -24)
        ])

        progressIndicator = indicator
        progressLabel = detailLabel

        // オーバーレイビューに参照を保持（後で削除するため）
        overlayView.identifier = NSUserInterfaceItemIdentifier("progressOverlay")

        // ボタンを無効化
        testButton.isEnabled = false
        saveButton.isEnabled = false
        cancelButton.isEnabled = false
    }

    @MainActor
    private func hideProgressIndicator() {
        progressIndicator?.stopAnimation(nil)

        // オーバーレイビューを削除
        if let overlayView = view.subviews.first(where: { $0.identifier?.rawValue == "progressOverlay" }) {
            overlayView.removeFromSuperview()
        }

        progressIndicator = nil
        progressLabel = nil

        // ボタンを有効化
        testButton.isEnabled = true
        saveButton.isEnabled = true
        cancelButton.isEnabled = true
    }

    @MainActor
    private func updateProgress(_ message: String) {
        progressLabel?.stringValue = message
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
