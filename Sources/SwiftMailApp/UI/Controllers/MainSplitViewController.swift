import AppKit
#if TARGET_INTERFACE_BUILDER

class AppEnvironment {}
class Account {}
class IMAPFolder {}

@MainActor
final class MainSplitViewController: NSSplitViewController, FolderListViewControllerDelegate, MessageListViewControllerDelegate {
    var environment: AppEnvironment?
}

#else

import SwiftMailCore

@MainActor
final class MainSplitViewController: NSSplitViewController {
    var environment: AppEnvironment? {
        didSet { configureIfReady() }
    }

    private var currentAccount: Account?
    private var currentFolder: IMAPFolder?
    private var hasLoadedInitialData = false

    private var folderController: FolderListViewController? {
        splitViewItems.first?.viewController as? FolderListViewController
    }

    private var messageListController: MessageListViewController? {
        guard splitViewItems.count > 1 else { return nil }
        return splitViewItems[1].viewController as? MessageListViewController
    }

    private var detailController: MessageDetailViewController? {
        splitViewItems.last?.viewController as? MessageDetailViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSplitView()
        configureChildControllers()
        configureIfReady()
    }

    private func configureSplitView() {
        splitView.dividerStyle = .thin
        splitView.isVertical = true
    }

    private func configureChildControllers() {
        folderController?.delegate = self
        messageListController?.delegate = self
    }

    private func configureIfReady() {
        guard !hasLoadedInitialData, isViewLoaded, let repository = environment?.repository else { return }
        hasLoadedInitialData = true
        loadInitialData(repository: repository)
    }

    private func loadInitialData(repository: MailRepository) {
        folderController?.showPlaceholder(text: "フォルダーを読み込み中…")
        messageListController?.setLoadingState()

        Task { [weak self] in
            guard let self else { return }
            do {
                let accounts = try await repository.fetchAccountsAsync()
                guard let account = accounts.first else {
                    await MainActor.run { self.presentNoAccountState() }
                    return
                }

                let folders = try await repository.fetchIMAPFoldersAsync(accountID: account.id)
                let normalizedFolders = self.normalizedFolders(for: account, sourceFolders: folders)
                let initialFolder = normalizedFolders.first
                let messages = try await repository.fetchMessagesAsync(
                    accountID: account.id,
                    folderID: initialFolder?.id,
                    limit: 50,
                    offset: 0
                )

                await MainActor.run {
                    self.currentAccount = account
                    self.currentFolder = initialFolder
                    self.folderController?.updateFolders(normalizedFolders)
                    self.folderController?.selectFolder(withID: initialFolder?.id)
                    self.messageListController?.updateMessages(messages)
                    self.messageListController?.selectMessage(withID: messages.first?.id)
                    self.detailController?.display(message: messages.first)
                }
            } catch {
                await MainActor.run {
                    self.folderController?.showPlaceholder(text: "フォルダーの読み込みに失敗しました\n\(error.localizedDescription)")
                    self.messageListController?.showPlaceholder(text: "メッセージの読み込みに失敗しました")
                    self.detailController?.display(message: nil)
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
        folderController?.showPlaceholder(text: "アカウントが設定されていません")
        messageListController?.showPlaceholder(text: "アカウントを追加してください")
        detailController?.display(message: nil)
    }

    private func loadMessages(for folder: IMAPFolder?) {
        guard let account = currentAccount else { return }
        messageListController?.setLoadingState()

        Task { [weak self] in
            guard let self else { return }
            do {
                guard let repository = self.environment?.repository else { return }
                let messages = try await repository.fetchMessagesAsync(
                    accountID: account.id,
                    folderID: folder?.id,
                    limit: 50,
                    offset: 0
                )
                await MainActor.run {
                    self.currentFolder = folder
                    self.messageListController?.updateMessages(messages)
                    self.messageListController?.selectMessage(withID: messages.first?.id)
                    self.detailController?.display(message: messages.first)
                }
            } catch {
                await MainActor.run {
                    self.messageListController?.showPlaceholder(text: "メッセージの読み込みに失敗しました")
                    self.detailController?.display(message: nil)
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
        detailController?.display(message: message)
    }
}

#endif
