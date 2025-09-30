import AppKit
import SwiftMailCore

@MainActor
final class MainSplitViewController: NSSplitViewController {
    private let environment: AppEnvironment
    private let repository: MailRepository
    private let syncService = MailSyncService()

    private let folderController = FolderListViewController()
    private let messageListController = MessageListViewController()
    private let detailController = MessageDetailViewController()

    private var currentAccount: Account?
    private var currentFolder: IMAPFolder?

    init(environment: AppEnvironment) {
        self.environment = environment
        self.repository = environment.repository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSplitView()
        loadInitialData()
    }

    private func configureSplitView() {
        splitView.dividerStyle = .thin
        splitView.isVertical = true

        folderController.delegate = self
        messageListController.delegate = self

        let folderItem = NSSplitViewItem(sidebarWithViewController: folderController)
        folderItem.minimumThickness = 220

        let listItem = NSSplitViewItem(viewController: messageListController)
        listItem.minimumThickness = 360

        let detailItem = NSSplitViewItem(viewController: detailController)
        detailItem.minimumThickness = 320

        addSplitViewItem(folderItem)
        addSplitViewItem(listItem)
        addSplitViewItem(detailItem)
    }

    private func loadInitialData() {
        folderController.showPlaceholder(text: "メールを同期中…")
        messageListController.setLoadingState()

        Task { [weak self] in
            guard let self else { return }
            do {
                // アカウントを取得
                let accounts = try await self.repository.fetchAccountsAsync()
                guard let account = accounts.first else {
                    await MainActor.run {
                        self.presentNoAccountState()
                    }
                    return
                }

                // サーバーからメールを同期
                await Task.detached {
                    do {
                        let syncCount = try await self.syncService.sync(account: account, repository: self.repository)
                        print("✅ \(syncCount)件のメールを同期しました")
                    } catch {
                        print("⚠️ メール同期エラー: \(error.localizedDescription)")
                        // 同期失敗してもローカルデータは表示
                    }
                }.value

                // ローカルデータを読み込み
                let folders = try await self.repository.fetchIMAPFoldersAsync(accountID: account.id)
                let normalizedFolders = self.normalizedFolders(for: account, sourceFolders: folders)
                let initialFolder = normalizedFolders.first
                let messages = try await self.repository.fetchMessagesAsync(
                    accountID: account.id,
                    folderID: initialFolder?.id,
                    limit: 50,
                    offset: 0
                )

                await MainActor.run {
                    self.currentAccount = account
                    self.currentFolder = initialFolder
                    self.folderController.updateFolders(normalizedFolders)
                    self.folderController.selectFolder(withID: initialFolder?.id)
                    self.messageListController.updateMessages(messages)
                    self.messageListController.selectMessage(withID: messages.first?.id)
                    self.detailController.display(message: messages.first)
                }
            } catch {
                await MainActor.run {
                    self.folderController.showPlaceholder(text: "データの読み込みに失敗しました\n\(error.localizedDescription)")
                    self.messageListController.showPlaceholder(text: "メッセージがありません")
                    self.detailController.display(message: nil)
                }
            }
        }
    }

    nonisolated private func normalizedFolders(for account: Account, sourceFolders: [IMAPFolder]) -> [IMAPFolder] {
        if !sourceFolders.isEmpty {
            return sourceFolders
        }
        let inbox = IMAPFolder(
            id: "inbox-\(account.id)",
            accountID: account.id,
            name: "受信トレイ",
            fullPath: "INBOX"
        )
        return [inbox]
    }

    private func presentNoAccountState() {
        folderController.showPlaceholder(text: "アカウントが設定されていません")
        messageListController.showPlaceholder(text: "アカウントを追加してください")
        detailController.display(message: nil)
    }

    func refreshData() {
        loadInitialData()
    }

    private func loadMessages(for folder: IMAPFolder?) {
        guard let account = currentAccount else { return }
        messageListController.setLoadingState()

        Task { [weak self] in
            guard let self else { return }
            do {
                let messages = try await self.repository.fetchMessagesAsync(
                    accountID: account.id,
                    folderID: folder?.id,
                    limit: 50,
                    offset: 0
                )
                await MainActor.run {
                    self.currentFolder = folder
                    self.messageListController.updateMessages(messages)
                    self.messageListController.selectMessage(withID: messages.first?.id)
                    self.detailController.display(message: messages.first)
                }
            } catch {
                await MainActor.run {
                    self.messageListController.showPlaceholder(text: "メッセージの読み込みに失敗しました")
                    self.detailController.display(message: nil)
                }
            }
        }
    }
}

extension MainSplitViewController: FolderListViewControllerDelegate {
    func folderListViewController(_ controller: FolderListViewController, didSelect folder: IMAPFolder?) {
        loadMessages(for: folder)
    }
}

extension MainSplitViewController: MessageListViewControllerDelegate {
    func messageListViewController(_ controller: MessageListViewController, didSelect message: Message?) {
        detailController.display(message: message)
    }
}
