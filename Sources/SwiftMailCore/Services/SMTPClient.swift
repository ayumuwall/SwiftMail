import Foundation
import Network

/// SMTP プロトコル実装（RFC 5321準拠）
public final class SMTPClient: @unchecked Sendable {

    public enum SMTPError: LocalizedError {
        case notConnected
        case authenticationFailed
        case invalidResponse(String)
        case connectionFailed(Error)
        case sendFailed(String)
        case recipientRejected(String)

        public var errorDescription: String? {
            switch self {
            case .notConnected:
                return "SMTPサーバーに接続されていません"
            case .authenticationFailed:
                return "認証に失敗しました"
            case .invalidResponse(let response):
                return "無効なレスポンス: \(response)"
            case .connectionFailed(let error):
                return "接続失敗: \(error.localizedDescription)"
            case .sendFailed(let reason):
                return "送信失敗: \(reason)"
            case .recipientRejected(let email):
                return "受信者が拒否されました: \(email)"
            }
        }
    }

    private let host: String
    private let port: Int
    private let useTLS: Bool

    private var connection: NWConnection?
    private var isConnected = false

    public init(host: String, port: Int = 587, useTLS: Bool = true) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
    }

    // MARK: - Connection Management

    /// SMTPサーバーに接続（STARTTLS対応）
    public func connect() async throws {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )

        // STARTTLS用の初期接続（平文）
        let parameters: NWParameters
        if useTLS && port == 465 {
            // SMTPS (implicit TLS)
            parameters = .tls
        } else {
            // SMTP with STARTTLS (explicit TLS)
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
                    continuation.resume(throwing: SMTPError.connectionFailed(error))
                case .waiting(let error):
                    self?.connection?.stateUpdateHandler = nil
                    continuation.resume(throwing: SMTPError.connectionFailed(error))
                default:
                    break
                }
            }

            connection?.start(queue: .main)
        }

        // サーバーのグリーティングを読み取る（220 ...）
        let greeting = try await receiveResponse()
        debugPrint("SMTP <- \(greeting)")
        guard greeting.hasPrefix("220") else {
            throw SMTPError.invalidResponse(greeting)
        }
    }

    /// サーバーから切断
    public func disconnect() async throws {
        guard let connection else {
            isConnected = false
            return
        }

        if isConnected {
            let quitData = Data("QUIT\r\n".utf8)
            try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                connection.send(content: quitData, completion: .contentProcessed { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                })
            }
        }

        connection.cancel()
        self.connection = nil
        isConnected = false
    }

    // MARK: - Authentication

    /// EHLOコマンドで機能確認
    public func ehlo(domain: String = "localhost") async throws -> [String] {
        guard isConnected else {
            throw SMTPError.notConnected
        }

        let response = try await sendCommand("EHLO \(domain)")
        debugPrint("SMTP <- \(response)")
        guard response.hasPrefix("250") else {
            throw SMTPError.invalidResponse(response)
        }

        // 拡張機能リストを抽出
        let lines = response.components(separatedBy: "\r\n")
        return lines.filter { $0.hasPrefix("250-") || $0.hasPrefix("250 ") }
    }

    /// STARTTLS実行（ポート587の場合）
    public func startTLS() async throws {
        guard isConnected else {
            throw SMTPError.notConnected
        }

        let response = try await sendCommand("STARTTLS")
        guard response.hasPrefix("220") else {
            throw SMTPError.invalidResponse(response)
        }

        // TLSアップグレード（Network frameworkの制約により簡易実装）
        // 実際の製品版では、接続を再確立する必要があります
    }

    /// AUTH LOGIN認証
    public func login(username: String, password: String) async throws {
        guard isConnected else {
            throw SMTPError.notConnected
        }

        // AUTH LOGIN開始
        let authResponse = try await sendCommand("AUTH LOGIN")
        guard authResponse.hasPrefix("334") else {
            throw SMTPError.authenticationFailed
        }

        // Base64エンコードされたユーザー名を送信
        let usernameBase64 = Data(username.utf8).base64EncodedString()
        let userResponse = try await sendCommand(usernameBase64)
        guard userResponse.hasPrefix("334") else {
            throw SMTPError.authenticationFailed
        }

        // Base64エンコードされたパスワードを送信
        let passwordBase64 = Data(password.utf8).base64EncodedString()
        let passResponse = try await sendCommand(passwordBase64, obfuscate: true)
        guard passResponse.hasPrefix("235") else {
            throw SMTPError.authenticationFailed
        }
    }

    // MARK: - Connection Testing

    /// 接続テスト（接続のみ確認して切断）
    public func testConnection() async throws {
        try await connect()
        try await disconnect()
    }

    // MARK: - Mail Sending

    /// メール送信（完全なトランザクション）
    public func sendMail(from: String, to: [String], message: String) async throws {
        guard isConnected else {
            throw SMTPError.notConnected
        }

        // MAIL FROM
        let mailFromResponse = try await sendCommand("MAIL FROM:<\(from)>")
        guard mailFromResponse.hasPrefix("250") else {
            throw SMTPError.sendFailed("MAIL FROM rejected: \(mailFromResponse)")
        }

        // RCPT TO（複数宛先対応）
        for recipient in to {
            let rcptResponse = try await sendCommand("RCPT TO:<\(recipient)>")
            guard rcptResponse.hasPrefix("250") else {
                throw SMTPError.recipientRejected(recipient)
            }
        }

        // DATA開始
        let dataResponse = try await sendCommand("DATA")
        guard dataResponse.hasPrefix("354") else {
            throw SMTPError.sendFailed("DATA command rejected: \(dataResponse)")
        }

        // メッセージ本体送信（最後は <CRLF>.<CRLF>）
        let fullMessage = message + "\r\n."
        let sendResponse = try await sendCommand(fullMessage)
        guard sendResponse.hasPrefix("250") else {
            throw SMTPError.sendFailed("Message rejected: \(sendResponse)")
        }
    }

    // MARK: - Private Helpers

    private func sendCommand(_ command: String, obfuscate: Bool = false) async throws -> String {
        guard let connection = connection else {
            throw SMTPError.notConnected
        }

        // コマンド送信（改行付き）
        let commandWithCRLF = command + "\r\n"
        let data = commandWithCRLF.data(using: .utf8)!

        if obfuscate {
            debugPrint("SMTP -> [redacted]")
        } else {
            debugPrint("SMTP -> \(command)")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }

        // レスポンス受信
        let response = try await receiveResponse()
        debugPrint("SMTP <- \(response)")
        return response
    }

    private func receiveResponse() async throws -> String {
        guard let connection = connection else {
            throw SMTPError.notConnected
        }

        var fullResponse = ""
        var iterationCount = 0
        let maxIterations = 100 // 無限ループ防止

        // マルチラインレスポンス対応（250-... と 250 ...）
        outerLoop: while iterationCount < maxIterations {
            iterationCount += 1

            let chunk = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let data = data, let response = String(data: data, encoding: .utf8) {
                        continuation.resume(returning: response)
                    } else {
                        continuation.resume(throwing: SMTPError.invalidResponse("Empty response"))
                    }
                }
            }

            if chunk.isEmpty {
                break
            }

            fullResponse += chunk

            // 改行が含まれている場合のみ判定
            if fullResponse.contains("\r\n") {
                let lines = fullResponse.components(separatedBy: "\r\n")
                for line in lines where line.count >= 4 {
                    let codePrefix = line.prefix(3)
                    guard Int(codePrefix) != nil else { continue }
                    let separatorIndex = line.index(line.startIndex, offsetBy: 3)
                    if line[separatorIndex] == " " {
                        break outerLoop
                    }
                }
            }

            // タイムアウト防止
            if fullResponse.count > 1_000_000 {
                throw SMTPError.invalidResponse("Response too large")
            }
        }

        if iterationCount >= maxIterations {
            throw SMTPError.invalidResponse("Too many iterations")
        }

        return fullResponse
    }
}
