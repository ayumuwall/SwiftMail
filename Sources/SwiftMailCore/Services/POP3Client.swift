import Foundation
import Network

/// POP3 プロトコル実装（RFC 1939準拠）
public final class POP3Client: @unchecked Sendable {

    public enum POP3Error: LocalizedError {
        case notConnected
        case authenticationFailed
        case invalidResponse(String)
        case connectionFailed(Error)
        case messageNotFound(Int)

        public var errorDescription: String? {
            switch self {
            case .notConnected:
                return "POP3サーバーに接続されていません"
            case .authenticationFailed:
                return "認証に失敗しました"
            case .invalidResponse(let response):
                return "無効なレスポンス: \(response)"
            case .connectionFailed(let error):
                return "接続失敗: \(error.localizedDescription)"
            case .messageNotFound(let num):
                return "メッセージ #\(num) が見つかりません"
            }
        }
    }

    private let host: String
    private let port: Int
    private let useTLS: Bool

    private var connection: NWConnection?
    private var isConnected = false

    public init(host: String, port: Int = 995, useTLS: Bool = true) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
    }

    // MARK: - Connection Management

    /// POP3サーバーに接続
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

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.connection?.stateUpdateHandler = nil
                    continuation.resume()
                case .failed(let error):
                    self?.connection?.stateUpdateHandler = nil
                    continuation.resume(throwing: POP3Error.connectionFailed(error))
                case .waiting(let error):
                    self?.connection?.stateUpdateHandler = nil
                    continuation.resume(throwing: POP3Error.connectionFailed(error))
                default:
                    break
                }
            }

            connection?.start(queue: .main)
        }

        // サーバーの初期応答を読み取る（+OK ...）
        _ = try await receiveResponse(expectsMultiline: false)
    }

    /// サーバーから切断
    public func disconnect() async throws {
        if isConnected {
            try await sendCommand("QUIT")
        }
        connection?.cancel()
        connection = nil
        isConnected = false
    }

    // MARK: - Authentication

    /// ユーザー認証（USER/PASS方式）
    public func login(username: String, password: String) async throws {
        guard isConnected else {
            throw POP3Error.notConnected
        }

        // USER コマンド
        let userResponse = try await sendCommand("USER \(username)")
        guard userResponse.hasPrefix("+OK") else {
            throw POP3Error.authenticationFailed
        }

        // PASS コマンド
        let passResponse = try await sendCommand("PASS \(password)")
        guard passResponse.hasPrefix("+OK") else {
            throw POP3Error.authenticationFailed
        }
    }

    // MARK: - Connection Testing

    /// 接続テスト（接続のみ確認して切断）
    public func testConnection() async throws {
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

        let testConnection = NWConnection(to: endpoint, using: parameters)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            testConnection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    testConnection.stateUpdateHandler = nil
                    testConnection.cancel()
                    continuation.resume()
                case .failed(let error):
                    testConnection.stateUpdateHandler = nil
                    continuation.resume(throwing: POP3Error.connectionFailed(error))
                case .waiting(let error):
                    testConnection.stateUpdateHandler = nil
                    continuation.resume(throwing: POP3Error.connectionFailed(error))
                default:
                    break
                }
            }

            testConnection.start(queue: .main)
        }
    }

    // MARK: - Mailbox Operations

    /// メールボックスの統計情報を取得
    public func stat() async throws -> MailboxStat {
        guard isConnected else {
            throw POP3Error.notConnected
        }

        let response = try await sendCommand("STAT")
        guard response.hasPrefix("+OK") else {
            throw POP3Error.invalidResponse(response)
        }

        // "+OK 3 120" のような形式から数値を抽出（余分な文言を無視）
        let line = firstLine(from: response)
        let tokens = line.split(separator: " ", omittingEmptySubsequences: true)

        var parsedNumbers: [Int] = []
        for token in tokens.dropFirst() {
            if let value = Int(token) {
                parsedNumbers.append(value)
                if parsedNumbers.count == 2 { break }
            }
        }

        guard parsedNumbers.count == 2 else {
            throw POP3Error.invalidResponse(response)
        }

        return MailboxStat(messageCount: parsedNumbers[0], totalSize: parsedNumbers[1])
    }

    /// メッセージリストを取得（番号とサイズ）
    public func list() async throws -> [MessageInfo] {
        guard isConnected else {
            throw POP3Error.notConnected
        }

        let response = try await sendCommand("LIST", expectsMultiline: true)
        guard response.hasPrefix("+OK") else {
            throw POP3Error.invalidResponse(response)
        }

        var messages: [MessageInfo] = []
        let lines = response.components(separatedBy: "\r\n")

        for line in lines.dropFirst() { // 最初の行は"+OK"なのでスキップ
            if line == "." { break } // 終端
            let components = line.components(separatedBy: " ")
            guard components.count >= 2,
                  let number = Int(components[0]),
                  let size = Int(components[1]) else {
                continue
            }
            messages.append(MessageInfo(number: number, size: size))
        }

        return messages
    }

    /// UIDL（Unique ID Listing）を取得
    public func uidl() async throws -> [String: String] {
        guard isConnected else {
            throw POP3Error.notConnected
        }

        let response = try await sendCommand("UIDL", expectsMultiline: true)
        guard response.hasPrefix("+OK") else {
            throw POP3Error.invalidResponse(response)
        }

        var uidlMap: [String: String] = [:]
        let lines = response.components(separatedBy: "\r\n")

        for line in lines.dropFirst() {
            if line == "." { break }
            let components = line.components(separatedBy: " ")
            guard components.count >= 2 else { continue }
            let number = components[0]
            let uidl = components[1]
            uidlMap[number] = uidl
        }

        return uidlMap
    }

    /// 特定のメッセージを取得
    public func retrieve(messageNumber: Int) async throws -> String {
        guard isConnected else {
            throw POP3Error.notConnected
        }

        let response = try await sendCommand("RETR \(messageNumber)", expectsMultiline: true)
        guard response.hasPrefix("+OK") else {
            if response.hasPrefix("-ERR") {
                throw POP3Error.messageNotFound(messageNumber)
            }
            throw POP3Error.invalidResponse(response)
        }

        // "+OK"の後にメッセージ本体が続く
        let lines = response.components(separatedBy: "\r\n")
        var messageLines = lines.dropFirst() // "+OK"行をスキップ

        // 最後の"."を除去
        if let lastLine = messageLines.last, lastLine == "." {
            messageLines = messageLines.dropLast()
        }

        return messageLines.joined(separator: "\r\n")
    }

    /// メッセージを削除マーク
    public func delete(messageNumber: Int) async throws {
        guard isConnected else {
            throw POP3Error.notConnected
        }

        let response = try await sendCommand("DELE \(messageNumber)")
        guard response.hasPrefix("+OK") else {
            throw POP3Error.invalidResponse(response)
        }
    }

    /// 削除マークをリセット
    public func reset() async throws {
        guard isConnected else {
            throw POP3Error.notConnected
        }

        let response = try await sendCommand("RSET")
        guard response.hasPrefix("+OK") else {
            throw POP3Error.invalidResponse(response)
        }
    }

    // MARK: - Private Helpers

    @discardableResult
    private func sendCommand(_ command: String, expectsMultiline: Bool = false) async throws -> String {
        guard let connection = connection else {
            throw POP3Error.notConnected
        }

        // コマンド送信（改行付き）
        let commandWithCRLF = command + "\r\n"
        let data = commandWithCRLF.data(using: .utf8)!

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
        return try await receiveResponse(expectsMultiline: expectsMultiline)
    }

    private func receiveResponse(expectsMultiline: Bool) async throws -> String {
        guard let connection = connection else {
            throw POP3Error.notConnected
        }

        var fullResponse = ""
        var iterationCount = 0
        let maxIterations = 100 // 無限ループ防止

        // マルチライン応答対応（LISTやUIDLなど）
        while iterationCount < maxIterations {
            iterationCount += 1

            // Taskがキャンセルされた場合は終了
            try Task.checkCancellation()

            let (chunk, isComplete) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(String, Bool), Error>) in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let data = data {
                        let response = String(decoding: data, as: UTF8.self)
                        continuation.resume(returning: (response, isComplete))
                    } else if isComplete {
                        continuation.resume(returning: ("", true))
                    } else {
                        continuation.resume(throwing: POP3Error.invalidResponse("Empty response"))
                    }
                }
            }

            if !chunk.isEmpty {
                fullResponse += chunk
            }

            if shouldFinishResponse(fullResponse, expectsMultiline: expectsMultiline) {
                break
            }

            if isComplete {
                break
            }

            // タイムアウト防止
            if fullResponse.count > 1_000_000 {
                throw POP3Error.invalidResponse("Response too large")
            }
        }

        if iterationCount >= maxIterations {
            throw POP3Error.invalidResponse("Too many iterations")
        }

        guard !fullResponse.isEmpty else {
            throw POP3Error.invalidResponse("Empty response")
        }

        return fullResponse
    }
}

private func firstLine(from response: String) -> String {
    if let range = response.range(of: "\r\n") {
        return String(response[..<range.lowerBound])
    }
    if let range = response.range(of: "\n") {
        return String(response[..<range.lowerBound])
    }
    if let range = response.range(of: "\r") {
        return String(response[..<range.lowerBound])
    }
    return response
}

private func shouldFinishResponse(_ response: String, expectsMultiline: Bool) -> Bool {
    guard !response.isEmpty else { return false }

    // エラー応答は単一行
    if response.hasPrefix("-ERR") {
        return response.contains("\r\n") || response.contains("\n")
    }

    guard response.hasPrefix("+OK") else {
        // 未知のレスポンス: 改行が来た時点で終了させて上位で検証
        return response.contains("\r\n") || response.contains("\n")
    }

    if expectsMultiline {
        // マルチライン終端は単独のドット行
        if response.hasSuffix("\r\n.\r\n") || response.hasSuffix("\n.\n") {
            return true
        }
        return false
    }

    // 単一行レスポンス
    return response.contains("\r\n") || response.contains("\n")
}

// MARK: - Supporting Types

public struct MailboxStat {
    public let messageCount: Int
    public let totalSize: Int

    public init(messageCount: Int, totalSize: Int) {
        self.messageCount = messageCount
        self.totalSize = totalSize
    }
}

public struct MessageInfo {
    public let number: Int
    public let size: Int

    public init(number: Int, size: Int) {
        self.number = number
        self.size = size
    }
}
