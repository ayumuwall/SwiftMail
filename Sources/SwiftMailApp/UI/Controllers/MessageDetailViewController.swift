import AppKit
import WebKit
import SwiftMailCore

@MainActor
final class MessageDetailViewController: NSViewController {
    private let placeholderLabel: NSTextField = {
        let label = NSTextField(labelWithString: "メッセージを選択してください")
        label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        label.textColor = NSColor.secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private let subjectLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2)
        label.textColor = NSColor.labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private let metadataLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = NSColor.secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private let bodyTextView: NSTextView = {
        let textView = NSTextView()
        textView.isEditable = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        return textView
    }()

    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        // セキュリティ設定（AGENTS.md準拠）
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.websiteDataStore = .nonPersistent()
        config.suppressesIncrementalRendering = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        return webView
    }()

    private let scrollView = NSScrollView()
    private var currentContentType: ContentType = .plain
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureLayout()
        updateUI(with: nil)
    }

    func display(message: Message?) {
        updateUI(with: message)
    }

    private func configureLayout() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = bodyTextView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        view.addSubview(placeholderLabel)
        view.addSubview(subjectLabel)
        view.addSubview(metadataLabel)
        view.addSubview(scrollView)
        view.addSubview(webView)

        webView.isHidden = true // 初期状態は非表示

        NSLayoutConstraint.activate([
            placeholderLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            placeholderLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8),

            subjectLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            subjectLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subjectLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            metadataLabel.topAnchor.constraint(equalTo: subjectLabel.bottomAnchor, constant: 4),
            metadataLabel.leadingAnchor.constraint(equalTo: subjectLabel.leadingAnchor),
            metadataLabel.trailingAnchor.constraint(equalTo: subjectLabel.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: metadataLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: subjectLabel.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: subjectLabel.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            // WebView制約（scrollViewと同じ位置）
            webView.topAnchor.constraint(equalTo: metadataLabel.bottomAnchor, constant: 12),
            webView.leadingAnchor.constraint(equalTo: subjectLabel.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: subjectLabel.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
    }

    private func updateUI(with message: Message?) {
        guard let message else {
            placeholderLabel.isHidden = false
            subjectLabel.isHidden = true
            metadataLabel.isHidden = true
            scrollView.isHidden = true
            webView.isHidden = true
            bodyTextView.string = ""
            return
        }

        placeholderLabel.isHidden = true
        subjectLabel.isHidden = false
        metadataLabel.isHidden = false

        subjectLabel.stringValue = message.subject ?? "(件名なし)"

        let senderText: String
        if let sender = message.sender {
            senderText = sender.name?.isEmpty == false ? "差出人: \(sender.name!) <\(sender.email)>" : "差出人: \(sender.email)"
        } else {
            senderText = "差出人: 不明"
        }

        let dateText: String
        if let date = message.date {
            dateText = Self.dateFormatter.string(from: date)
        } else {
            dateText = ""
        }

        metadataLabel.stringValue = [senderText, dateText].filter { !$0.isEmpty }.joined(separator: "\n")

        // HTMLとプレーンテキストの判定
        if let htmlBody = message.bodyHTML, !htmlBody.isEmpty {
            displayHTML(htmlBody)
        } else if let plainBody = message.bodyPlain {
            displayPlainText(plainBody)
        } else {
            displayPlainText("本文がありません")
        }
    }

    private func displayPlainText(_ text: String) {
        currentContentType = .plain
        scrollView.isHidden = false
        webView.isHidden = true
        bodyTextView.string = text
    }

    private func displayHTML(_ html: String) {
        currentContentType = .html
        scrollView.isHidden = true
        webView.isHidden = false

        // CSP (Content Security Policy) を適用してセキュリティ強化
        let secureHTML = """
        <html>
        <head>
            <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'none'; style-src 'unsafe-inline';">
            <meta charset="UTF-8">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
                    font-size: 13px;
                    line-height: 1.6;
                    padding: 0;
                    margin: 0;
                }
            </style>
        </head>
        <body>
        \(html)
        </body>
        </html>
        """

        webView.loadHTMLString(secureHTML, baseURL: nil)
    }

    private enum ContentType {
        case plain
        case html
    }
}

