import Foundation

/// RFC 5322準拠のメールメッセージ作成ユーティリティ
public final class MessageComposer {

    public enum ComposerError: LocalizedError {
        case invalidAddress(String)
        case missingRecipient

        public var errorDescription: String? {
            switch self {
            case .invalidAddress(let email):
                return "無効なメールアドレス: \(email)"
            case .missingRecipient:
                return "宛先が指定されていません"
            }
        }
    }

    public init() {}

    /// メールメッセージを作成
    public func compose(
        from: EmailAddress,
        to: [EmailAddress],
        cc: [EmailAddress] = [],
        bcc: [EmailAddress] = [],
        subject: String,
        body: String,
        isHTML: Bool = false,
        messageId: String? = nil,
        inReplyTo: String? = nil,
        references: [String] = []
    ) throws -> String {
        // 宛先チェック
        guard !to.isEmpty else {
            throw ComposerError.missingRecipient
        }

        var headers: [String] = []

        // Message-ID（自動生成または指定）
        let finalMessageId = messageId ?? generateMessageId(from: from.email)
        headers.append("Message-ID: \(finalMessageId)")

        // Date（RFC 5322形式）
        headers.append("Date: \(formatDate(Date()))")

        // From
        headers.append("From: \(formatAddress(from))")

        // To
        headers.append("To: \(to.map { formatAddress($0) }.joined(separator: ", "))")

        // Cc
        if !cc.isEmpty {
            headers.append("Cc: \(cc.map { formatAddress($0) }.joined(separator: ", "))")
        }

        // Subject（UTF-8エンコード対応）
        headers.append("Subject: \(encodeSubject(subject))")

        // In-Reply-To（返信時）
        if let inReplyTo = inReplyTo {
            headers.append("In-Reply-To: \(inReplyTo)")
        }

        // References（スレッド追跡）
        if !references.isEmpty {
            headers.append("References: \(references.joined(separator: " "))")
        }

        // MIME-Version
        headers.append("MIME-Version: 1.0")

        // Content-Type
        if isHTML {
            headers.append("Content-Type: text/html; charset=UTF-8")
        } else {
            headers.append("Content-Type: text/plain; charset=UTF-8")
        }

        headers.append("Content-Transfer-Encoding: 8bit")

        // ヘッダーとボディを結合
        let headerText = headers.joined(separator: "\r\n")
        return "\(headerText)\r\n\r\n\(body)"
    }

    // MARK: - Private Helpers

    /// メールアドレスをRFC 5322形式にフォーマット
    private func formatAddress(_ address: EmailAddress) -> String {
        if let name = address.name, !name.isEmpty {
            // "Name" <email@example.com>
            return "\"\(name)\" <\(address.email)>"
        } else {
            // email@example.com
            return address.email
        }
    }

    /// 件名をエンコード（マルチバイト文字対応）
    private func encodeSubject(_ subject: String) -> String {
        // ASCII範囲内ならそのまま
        if subject.allSatisfy({ $0.isASCII }) {
            return subject
        }

        // UTF-8 Base64エンコード（RFC 2047）
        let encoded = Data(subject.utf8).base64EncodedString()
        return "=?UTF-8?B?\(encoded)?="
    }

    /// 日付をRFC 5322形式にフォーマット
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.string(from: date)
    }

    /// Message-IDを生成
    private func generateMessageId(from email: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = UUID().uuidString.prefix(8)
        let domain = email.split(separator: "@").last ?? "localhost"
        return "<\(timestamp).\(random)@\(domain)>"
    }
}
