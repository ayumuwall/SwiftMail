import AppKit

@MainActor
final class MainWindowController: NSWindowController {
    private let environment: AppEnvironment
    private var splitViewController: MainSplitViewController?

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

        let splitVC = MainSplitViewController(environment: environment)
        self.splitViewController = splitVC
        window.contentViewController = splitVC

        configureToolbar()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureToolbar() {
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        window?.toolbar = toolbar
    }

    @objc private func composeButtonTapped() {
        let composeVC = MessageComposeViewController()
        composeVC.onSend = { composedMessage in
            print("📧 送信: \(composedMessage.subject)")
            // TODO: 実際の送信処理を実装
        }

        let window = NSWindow(contentViewController: composeVC)
        window.title = "メール作成"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 500))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func accountsButtonTapped() {
        let accountListVC = AccountListViewController()

        // 既存アカウントを読み込み
        Task {
            do {
                let accounts = try await environment.repository.fetchAccountsAsync()
                await MainActor.run {
                    accountListVC.setAccounts(accounts)
                }
            } catch {
                print("⚠️ アカウント読み込みエラー: \(error)")
            }
        }

        // アカウント変更時の処理
        accountListVC.onAccountsChanged = { [weak self] accounts in
            guard let self = self else { return }
            Task.detached {
                // 全アカウントをデータベースに保存
                for account in accounts {
                    do {
                        try self.environment.repository.upsertAccount(account)
                    } catch {
                        print("⚠️ アカウント保存エラー: \(error)")
                    }
                }
                // メインビューを更新
                await MainActor.run {
                    self.splitViewController?.refreshData()
                }
            }
        }

        let window = NSWindow(contentViewController: accountListVC)
        window.title = "アカウント管理"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 400, height: 500))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func refreshButtonTapped() {
        splitViewController?.refreshData()
    }
}

extension MainWindowController: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .compose:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "作成"
            item.paletteLabel = "メール作成"
            item.toolTip = "新規メールを作成"
            item.target = self
            item.action = #selector(composeButtonTapped)
            item.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "作成")
            return item

        case .accounts:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "アカウント"
            item.paletteLabel = "アカウント管理"
            item.toolTip = "アカウントを管理"
            item.target = self
            item.action = #selector(accountsButtonTapped)
            item.image = NSImage(systemSymbolName: "person.circle", accessibilityDescription: "アカウント")
            return item

        case .refresh:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "更新"
            item.paletteLabel = "メール更新"
            item.toolTip = "メールを更新"
            item.target = self
            item.action = #selector(refreshButtonTapped)
            item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "更新")
            return item

        default:
            return nil
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.compose, .refresh, .flexibleSpace, .accounts]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.compose, .accounts, .refresh, .flexibleSpace, .space]
    }
}

extension NSToolbarItem.Identifier {
    static let compose = NSToolbarItem.Identifier("compose")
    static let accounts = NSToolbarItem.Identifier("accounts")
    static let refresh = NSToolbarItem.Identifier("refresh")
}
