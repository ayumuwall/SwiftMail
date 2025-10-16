import Foundation
import Network

/// IMAP プロトコル実装（RFC 3501準拠）
public final class IMAPClient: @unchecked Sendable {

    public enum IMAPError: LocalizedError {
        case notConnected
        case authenticationFailed
        case invalidResponse(String)
        case connectionFailed(Error)
        case timeout

        public var errorDescription: String? {
            switch self {
            case .notConnected:
                return "IMAPサーバーに接続されていません"
            case .authenticationFailed:
                return "認証に失敗しました"
            case .invalidResponse(let response):
                return "無効なレスポンス: \(response)"
            case .connectionFailed(let error):
                return "接続失敗: \(error.localizedDescription)"
            case .timeout:
                return "タイムアウトしました"
            }
        }
    }

    private let host: String
    private let port: Int
    private let useTLS: Bool

    private var connection: NWConnection?
    private var tagCounter = 0
    private var isConnected = false

    public init(host: String, port: Int = 993, useTLS: Bool = true) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
    }

    // MARK: - Connection Management

    /// IMAPサーバーに接続
    public func connect() async throws {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )

        let parameters: NWParameters
        if useTLS {
            parameters = .tls
        } else {
            parameters = .tcp
        }

        connection = NWConnection(to: endpoint, using: parameters)

        try await withCheckedThrowingContinuation { continuation in
            connection?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.connection?.stateUpdateHandler = nil
                    continuation.resume()
                case .failed(let error):
                    self?.connection?.stateUpdateHandler = nil
                    continuation.resume(throwing: IMAPError.connectionFailed(error))
                case .waiting(let error):
                    self?.connection?.stateUpdateHandler = nil
                    continuation.resume(throwing: IMAPError.connectionFailed(error))
                default:
                    break
                }
            }

            connection?.start(queue: .main)
        }

        let greeting = try await receiveResponse()
        debugPrint("IMAP <- \(greeting.trimmingCharacters(in: .whitespacesAndNewlines))")
        guard greeting.contains("OK") else {
            throw IMAPError.invalidResponse(greeting)
        }
    }

    /// サーバーから切断
    public func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
    }

    // MARK: - Authentication

    /// ログイン認証
    public func login(email: String, password: String) async throws {
        guard isConnected else {
            throw IMAPError.notConnected
        }

        let tag = nextTag()
        let command = "\(tag) LOGIN \(email) \(password)\r\n"

        let response = try await sendCommand(command, obfuscate: true)

        // レスポンスチェック（簡易実装）
        if !response.contains("\(tag) OK") {
            throw IMAPError.authenticationFailed
        }
    }

    // MARK: - Folder Operations

    /// フォルダーリストを取得
    public func listFolders() async throws -> [String] {
        guard isConnected else {
            throw IMAPError.notConnected
        }

        let tag = nextTag()
        let command = "\(tag) LIST \"\" \"*\"\r\n"

        let response = try await sendCommand(command)

        // フォルダー名を抽出（簡易実装）
        var folders: [String] = []
        let lines = response.components(separatedBy: "\r\n")
        for line in lines {
            if line.hasPrefix("* LIST") {
                // "* LIST (...) "/" "INBOX" のようなフォーマットからフォルダー名を抽出
                if let lastQuote = line.lastIndex(of: "\""),
                   let secondLastQuote = line[..<lastQuote].lastIndex(of: "\"") {
                    let folderName = String(line[line.index(after: secondLastQuote)..<lastQuote])
                    folders.append(folderName)
                }
            }
        }

        return folders
    }

    /// フォルダーを選択
    public func selectFolder(_ folderName: String) async throws -> FolderInfo {
        guard isConnected else {
            throw IMAPError.notConnected
        }

        let tag = nextTag()
        let command = "\(tag) SELECT \"\(folderName)\"\r\n"

        let response = try await sendCommand(command)
        debugPrint("IMAP SELECT response:\n\(response)")

        // メッセージ数とUIDNEXTを抽出（簡易実装）
        var messageCount = 0
        var uidNext: Int?

        let lines = response.components(separatedBy: "\r\n")
        for line in lines {
            if line.contains("EXISTS") {
                let components = line.components(separatedBy: " ")
                if let count = components.first(where: { Int($0) != nil }) {
                    messageCount = Int(count) ?? 0
                }
            } else if line.contains("UIDNEXT") {
                let components = line.components(separatedBy: " ")
                if let uidNextStr = components.last?.replacingOccurrences(of: "]", with: "") {
                    uidNext = Int(uidNextStr)
                }
            }
        }

        return FolderInfo(name: folderName, messageCount: messageCount, uidNext: uidNext)
    }

    // MARK: - Connection Testing

    /// 接続テスト（接続のみ確認して切断）
    public func testConnection() async throws {
        try await connect()
        disconnect()
    }

    // MARK: - Message Operations

    /// メッセージヘッダーを取得
    public func fetchHeaders(range: ClosedRange<Int>) async throws -> [String] {
        guard isConnected else {
            throw IMAPError.notConnected
        }

        let tag = nextTag()
        let command = "\(tag) FETCH \(range.lowerBound):\(range.upperBound) (BODY.PEEK[HEADER])\r\n"

        let response = try await sendCommand(command)
        debugPrint("IMAP FETCH raw response:\n\(response)")

        let extracted = extractHeaders(from: response)
        if extracted.isEmpty {
            debugPrint("IMAP FETCH: failed to extract headers, returning raw response")
            return [response]
        }
        return extracted
    }

    // MARK: - Private Helpers

    private func nextTag() -> String {
        tagCounter += 1
        return "A\(String(format: "%04d", tagCounter))"
    }

    private func sendCommand(_ command: String, obfuscate: Bool = false) async throws -> String {
        guard let connection = connection else {
            throw IMAPError.notConnected
        }

        // コマンド送信
        let data = command.data(using: .utf8)!

        if obfuscate {
            debugPrint("IMAP -> [redacted]")
        } else {
            debugPrint("IMAP -> \(command.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }

        // レスポンス受信
        let response = try await receiveResponse()
        debugPrint("IMAP <- \(response.trimmingCharacters(in: .whitespacesAndNewlines))")
        return response
    }

    private func receiveResponse() async throws -> String {
        guard let connection = connection else {
            throw IMAPError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: response)
                } else {
                    continuation.resume(throwing: IMAPError.invalidResponse("Empty response"))
                }
            }
        }
    }

    private func extractHeaders(from response: String) -> [String] {
        var headers: [String] = []
        var searchRange = response.startIndex..<response.endIndex

        while let bodyRange = response.range(of: "BODY[HEADER]", options: [], range: searchRange) {
            guard let closingBraceRange = response.range(of: "}\r\n", options: [], range: bodyRange.upperBound..<response.endIndex) else {
                break
            }
            let headerStart = closingBraceRange.upperBound

            guard let terminatorRange = response.range(of: "\r\n)\r\n", options: [], range: headerStart..<response.endIndex) else {
                break
            }

            let header = String(response[headerStart..<terminatorRange.lowerBound])
            headers.append(header)

            searchRange = terminatorRange.upperBound..<response.endIndex
        }

        return headers
    }
}

// MARK: - Supporting Types

public struct FolderInfo {
    public let name: String
    public let messageCount: Int
    public let uidNext: Int?

    public init(name: String, messageCount: Int, uidNext: Int?) {
        self.name = name
        self.messageCount = messageCount
        self.uidNext = uidNext
    }
}
