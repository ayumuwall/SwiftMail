import Foundation

/// RFC 822/RFC 2822準拠のメールメッセージパーサー
public final class MessageParser: Sendable {

    public enum ParseError: LocalizedError {
        case invalidFormat
        case missingHeaders
        case invalidEncoding

        public var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "メッセージフォーマットが無効です"
            case .missingHeaders:
                return "必須ヘッダーが見つかりません"
            case .invalidEncoding:
                return "エンコーディングが無効です"
            }
        }
    }

    public init() {}

    /// RFC822形式の生メッセージをパース
    public func parse(rawMessage: String) throws -> ParsedMessage {
        // メッセージをヘッダーとボディに分割
        let parts = rawMessage.components(separatedBy: "\r\n\r\n")
        guard parts.count >= 2 else {
            // ヘッダーのみの場合も許容
            if parts.count == 1 {
                return try parseHeadersOnly(parts[0])
            }
            throw ParseError.invalidFormat
        }

        let headerText = parts[0]
        let bodyText = parts.dropFirst().joined(separator: "\r\n\r\n")

        let headers = try parseHeaders(headerText)
        let body = parseBody(bodyText, headers: headers)

        return ParsedMessage(
            messageId: headers["Message-ID"],
            subject: headers["Subject"],
            from: parseAddress(headers["From"]),
            to: parseAddresses(headers["To"]),
            cc: parseAddresses(headers["Cc"]),
            date: parseDate(headers["Date"]),
            bodyPlain: body.plain,
            bodyHTML: body.html,
            rawHeaders: headers
        )
    }

    /// ヘッダーのみのメッセージをパース
    private func parseHeadersOnly(_ headerText: String) throws -> ParsedMessage {
        let headers = try parseHeaders(headerText)

        return ParsedMessage(
            messageId: headers["Message-ID"],
            subject: headers["Subject"],
            from: parseAddress(headers["From"]),
            to: parseAddresses(headers["To"]),
            cc: parseAddresses(headers["Cc"]),
            date: parseDate(headers["Date"]),
            bodyPlain: nil,
            bodyHTML: nil,
            rawHeaders: headers
        )
    }

    /// ヘッダーをパース
    private func parseHeaders(_ headerText: String) throws -> [String: String] {
        var headers: [String: String] = [:]
        var currentKey: String?
        var currentValue = ""

        let lines = headerText.components(separatedBy: "\r\n")

        for line in lines {
            if line.isEmpty { continue }

            // 折り返し行（先頭がスペースまたはタブ）
            if line.first == " " || line.first == "\t" {
                currentValue += line.trimmingCharacters(in: .whitespaces)
            } else {
                // 前のヘッダーを保存
                if let key = currentKey {
                    headers[key] = currentValue.trimmingCharacters(in: .whitespaces)
                }

                // 新しいヘッダー
                let components = line.split(separator: ":", maxSplits: 1)
                guard components.count == 2 else { continue }

                currentKey = String(components[0]).trimmingCharacters(in: .whitespaces)
                currentValue = String(components[1]).trimmingCharacters(in: .whitespaces)
            }
        }

        // 最後のヘッダーを保存
        if let key = currentKey {
            headers[key] = currentValue.trimmingCharacters(in: .whitespaces)
        }

        return headers
    }

    /// ボディをパース（プレーンテキストとHTML）
    private func parseBody(_ bodyText: String, headers: [String: String]) -> (plain: String?, html: String?) {
        // Content-Typeヘッダーを確認
        guard let contentType = headers["Content-Type"] else {
            // Content-Typeがない場合はプレーンテキストとして扱う
            return (plain: bodyText, html: nil)
        }

        // マルチパート対応は将来実装
        // 現時点ではシンプルなケースのみ対応
        if contentType.lowercased().contains("text/html") {
            return (plain: nil, html: bodyText)
        } else {
            return (plain: bodyText, html: nil)
        }
    }

    /// メールアドレスをパース（"Name <email@example.com>" 形式対応）
    private func parseAddress(_ addressString: String?) -> EmailAddress? {
        guard let addressString = addressString else { return nil }

        // "Name <email@example.com>" 形式
        if let rangeStart = addressString.range(of: "<"),
           let rangeEnd = addressString.range(of: ">") {
            let email = String(addressString[rangeStart.upperBound..<rangeEnd.lowerBound])
            let name = addressString[..<rangeStart.lowerBound]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return EmailAddress(email: email, name: name.isEmpty ? nil : name)
        }

        // "email@example.com" 形式のみ
        let trimmed = addressString.trimmingCharacters(in: .whitespaces)
        return EmailAddress(email: trimmed, name: nil)
    }

    /// 複数のメールアドレスをパース（カンマ区切り）
    private func parseAddresses(_ addressesString: String?) -> [EmailAddress] {
        guard let addressesString = addressesString else { return [] }

        let addresses = addressesString.components(separatedBy: ",")
        return addresses.compactMap { parseAddress($0) }
    }

    /// 日付をパース（RFC 2822形式）
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"

        return formatter.date(from: dateString)
    }
}

// MARK: - Parsed Message Model

public struct ParsedMessage {
    public let messageId: String?
    public let subject: String?
    public let from: EmailAddress?
    public let to: [EmailAddress]
    public let cc: [EmailAddress]
    public let date: Date?
    public let bodyPlain: String?
    public let bodyHTML: String?
    public let rawHeaders: [String: String]

    public init(
        messageId: String?,
        subject: String?,
        from: EmailAddress?,
        to: [EmailAddress],
        cc: [EmailAddress],
        date: Date?,
        bodyPlain: String?,
        bodyHTML: String?,
        rawHeaders: [String: String]
    ) {
        self.messageId = messageId
        self.subject = subject
        self.from = from
        self.to = to
        self.cc = cc
        self.date = date
        self.bodyPlain = bodyPlain
        self.bodyHTML = bodyHTML
        self.rawHeaders = rawHeaders
    }
}

public struct EmailAddress: Codable, Equatable {
    public let email: String
    public let name: String?

    public init(email: String, name: String?) {
        self.email = email
        self.name = name
    }

    public var displayName: String {
        name ?? email
    }
}
