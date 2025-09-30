import Foundation

/// メール同期サービス（IMAP/POP3からメールを取得しデータベースに保存）
public final class MailSyncService: Sendable {

    // MARK: - Helper Methods

    private func convertAddress(_ emailAddress: EmailAddress) -> Message.Address {
        return Message.Address(name: emailAddress.name, email: emailAddress.email)
    }

    private func convertAddresses(_ emailAddresses: [EmailAddress]) -> [Message.Address] {
        return emailAddresses.map { convertAddress($0) }
    }

    public enum SyncError: LocalizedError {
        case accountNotFound
        case connectionFailed(Error)
        case authenticationFailed
        case parsingFailed(Error)
        case saveFailed(Error)

        public var errorDescription: String? {
            switch self {
            case .accountNotFound:
                return "アカウントが見つかりません"
            case .connectionFailed(let error):
                return "接続に失敗しました: \(error.localizedDescription)"
            case .authenticationFailed:
                return "認証に失敗しました"
            case .parsingFailed(let error):
                return "メッセージの解析に失敗しました: \(error.localizedDescription)"
            case .saveFailed(let error):
                return "メッセージの保存に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    private let keychainManager = KeychainManager()
    private let messageParser = MessageParser()

    public init() {}

    /// IMAPでメールを同期
    public func syncIMAP(account: Account, repository: MailRepository) async throws -> Int {
        guard let imapHost = account.imapHost else {
            throw SyncError.accountNotFound
        }

        // Keychainからパスワードを取得
        guard let password = try? keychainManager.retrievePassword(for: account.id) else {
            throw SyncError.authenticationFailed
        }

        // IMAP接続
        let client = IMAPClient(host: imapHost, port: account.imapPort, useTLS: true)

        do {
            try await client.connect()
        } catch {
            throw SyncError.connectionFailed(error)
        }

        // ログイン
        do {
            try await client.login(email: account.email, password: password)
        } catch {
            client.disconnect()
            throw SyncError.authenticationFailed
        }

        // フォルダー一覧を取得
        let folderNames: [String]
        do {
            folderNames = try await client.listFolders()
        } catch {
            client.disconnect()
            throw SyncError.connectionFailed(error)
        }

        var totalSynced = 0

        // 各フォルダーからメッセージを取得
        for folderName in folderNames {
            do {
                let folderInfo = try await client.selectFolder(folderName)

                // フォルダーをデータベースに保存
                let folder = IMAPFolder(
                    id: "\(account.id)-\(folderName)",
                    accountID: account.id,
                    name: folderName,
                    fullPath: folderName
                )
                try repository.upsertIMAPFolders([folder])

                // メッセージヘッダーを取得（最新50件）
                if folderInfo.messageCount > 0 {
                    let count = min(folderInfo.messageCount, 50)
                    let headers = try await client.fetchHeaders(range: 1...count)

                    // 簡易実装: 最初のヘッダーのみパース
                    // TODO: 実際は全メッセージを個別に取得・パース
                    if let headerText = headers.first {
                        if let parsedMessage = try? messageParser.parse(rawMessage: headerText) {
                            let message = Message(
                                id: parsedMessage.messageId ?? UUID().uuidString,
                                accountID: account.id,
                                messageID: parsedMessage.messageId,
                                folderID: folder.id,
                                subject: parsedMessage.subject,
                                sender: parsedMessage.from.map { convertAddress($0) },
                                recipients: convertAddresses(parsedMessage.to + parsedMessage.cc),
                                date: parsedMessage.date,
                                size: 0,
                                headers: parsedMessage.rawHeaders,
                                bodyPlain: parsedMessage.bodyPlain,
                                bodyHTML: parsedMessage.bodyHTML,
                                isRead: false,
                                isFlagged: false,
                                isDeleted: false,
                                cachedAt: Date()
                            )
                            try repository.saveMessages([message])
                            totalSynced += 1
                        }
                    }
                }
            } catch {
                print("⚠️ フォルダー \(folderName) の同期に失敗: \(error)")
                continue
            }
        }

        client.disconnect()
        return totalSynced
    }

    /// POP3でメールを同期
    public func syncPOP3(account: Account, repository: MailRepository) async throws -> Int {
        guard account.serverType == .pop3 else {
            throw SyncError.accountNotFound
        }

        // POP3はimapHostを使用（サーバー設定の都合）
        guard let pop3Host = account.imapHost else {
            throw SyncError.accountNotFound
        }

        // Keychainからパスワードを取得
        guard let password = try? keychainManager.retrievePassword(for: account.id) else {
            throw SyncError.authenticationFailed
        }

        // POP3接続
        let client = POP3Client(host: pop3Host, port: account.imapPort, useTLS: true)

        do {
            try await client.connect()
        } catch {
            throw SyncError.connectionFailed(error)
        }

        // ログイン
        do {
            try await client.login(username: account.email, password: password)
        } catch {
            try? await client.disconnect()
            throw SyncError.authenticationFailed
        }

        // メッセージ統計を取得
        let stat: MailboxStat
        do {
            stat = try await client.stat()
        } catch {
            try? await client.disconnect()
            throw SyncError.connectionFailed(error)
        }

        var totalSynced = 0

        // メッセージを取得（最新50件まで）
        let count = min(stat.messageCount, 50)
        for messageNumber in 1...count {
            do {
                let rawMessage = try await client.retrieve(messageNumber: messageNumber)
                let parsedMessage = try messageParser.parse(rawMessage: rawMessage)

                let message = Message(
                    id: parsedMessage.messageId ?? UUID().uuidString,
                    accountID: account.id,
                    messageID: parsedMessage.messageId,
                    folderID: nil,
                    subject: parsedMessage.subject,
                    sender: parsedMessage.from.map { convertAddress($0) },
                    recipients: convertAddresses(parsedMessage.to + parsedMessage.cc),
                    date: parsedMessage.date,
                    size: 0,
                    headers: parsedMessage.rawHeaders,
                    bodyPlain: parsedMessage.bodyPlain,
                    bodyHTML: parsedMessage.bodyHTML,
                    isRead: false,
                    isFlagged: false,
                    isDeleted: false,
                    cachedAt: Date()
                )
                try repository.saveMessages([message])
                totalSynced += 1
            } catch {
                print("⚠️ メッセージ #\(messageNumber) の同期に失敗: \(error)")
                continue
            }
        }

        try? await client.disconnect()
        return totalSynced
    }

    /// アカウントの種類に応じて自動的に同期
    public func sync(account: Account, repository: MailRepository) async throws -> Int {
        switch account.serverType {
        case .imap:
            return try await syncIMAP(account: account, repository: repository)
        case .pop3:
            return try await syncPOP3(account: account, repository: repository)
        }
    }
}
