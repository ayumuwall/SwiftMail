# SwiftMail - Claude Code 開発ガイド

## プロジェクト概要

SwiftMailは、macOS専用の軽量メールクライアントです。Thunderbirdなどの肥大化したメールクライアントとは対照的に、メールの読み書きという本質的な機能のみに特化しています。

### 開発思想
- **Minimalism First**: 機能を追加するのではなく、削ることを重視
- **Performance Focused**: 高速起動と軽快な動作を最優先
- **Native Experience**: macOSのHuman Interface Guidelinesに完全準拠

### パフォーマンス目標値
- 起動時間: < 1秒
- メール一覧表示: < 100ms（1000件）
- 検索レスポンス: < 200ms（ローカル）
- メモリ使用量: < 100MB（通常使用時）
- CPU使用率: < 5%（アイドル時）

## Feature Creep防止ルール

### 実装してはいけない機能リスト
```
❌ カレンダー統合
❌ タスク管理
❌ RSS購読
❌ チャット機能
❌ プラグインシステム
❌ テーマカスタマイズ
❌ 複雑なフィルタールール
❌ 自動分類・AI機能
❌ ソーシャルメディア統合
❌ 拡張機能・アドオン
```

## アーキテクチャ原則

### MVC + Repository パターン
```
View Layer (AppKit) → Controller Layer → Service Layer → Repository Layer
```

### 依存関係の制約
- **外部ライブラリは禁止**: 可能な限りFoundation/AppKitの標準機能のみを使用
- **例外**: セキュリティ上必要不可欠な場合のみ最小限の依存を許可
- **理由**: 軽量性の維持、長期的なメンテナンス性の確保

### POP3 vs IMAP 処理の分離
```swift
protocol MailProtocol {
    func connect() async throws
    func fetchMessages() async throws -> [Message]
    func deleteMessage(_ id: String) async throws
}

// POP3特有の制約事項
// - フォルダー概念なし → 受信トレイのみ
// - サーバー側の既読管理なし → ローカル管理
// - UIDL対応必須（重複ダウンロード防止）

// IMAP特有の機能
// - フォルダー階層対応
// - サーバー側の既読/フラグ管理
// - 部分フェッチ対応
```

## データ同期・キャッシュ戦略

### キャッシュポリシー
```swift
struct CachePolicy {
    static let recentMailsDays = 30        // 直近30日分はフルキャッシュ
    static let headerOnlyAfterDays = 30    // それ以前はヘッダーのみ
    static let attachmentPolicy = AttachmentPolicy.onDemand
}
```

### 同期アルゴリズム
```swift
enum SyncStrategy {
    case full        // 初回同期時
    case incremental // 通常の差分同期
    case headers     // ヘッダーのみ（高速モード）
}

struct SyncSchedule {
    case manual
    case automatic(interval: TimeInterval) // 5, 15, 30分
}
```

### データ保存場所
- メールデータ: `~/Library/Application Support/SwiftMail/`
- 設定: UserDefaults（機密情報以外）
- 認証情報: Keychain
- 添付ファイルキャッシュ: `~/Library/Caches/SwiftMail/`

## Swift コーディング規約

### 命名規則
```swift
// クラス名: PascalCase
class MailListViewController: NSViewController

// 変数・関数名: camelCase
var messageCount: Int
func loadMessages() -> [Message]

// 定数: UpperCamelCase（Swiftの慣例に従う）
static let MaxRetryCount = 3

// プライベートプロパティ: アンダースコア不要
private var isLoading = false
```

### ファイル構成規則
```
- 1ファイル1クラス原則
- ファイル名はクラス名と完全一致
- extensionは別ファイルに分離（Example: Message+Parsing.swift）
- テストファイル: ClassNameTests.swift
```

### メモリ管理
```swift
// 必須: weak参照でサイクル参照を防ぐ
weak var delegate: MailListDelegate?

// 必須: @escaping クロージャーでは weak self を使用
networkService.fetchMails { [weak self] result in
    self?.handleResult(result)
}

// 推奨: lazy var で重い初期化を遅延
lazy var messageParser = MessageParser()
```

## UI/UX実装ガイドライン

### AppKit使用原則
```swift
// 好ましい: Auto Layoutを使用
view.translatesAutoresizingMaskIntoConstraints = false
NSLayoutConstraint.activate([
    view.topAnchor.constraint(equalTo: superview.topAnchor),
    view.leadingAnchor.constraint(equalTo: superview.leadingAnchor)
])

// 避ける: フレームベースのレイアウト（特別な理由がない限り）
view.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
```

### カラー・フォント指針
```swift
// システムカラーの使用を優先
let textColor = NSColor.labelColor
let backgroundColor = NSColor.controlBackgroundColor

// システムフォントの使用を優先
let bodyFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
let titleFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2)
```

### 必須キーボードショートカット（Mail.app互換）
```swift
// GlobalShortcuts.swift
enum KeyboardShortcut {
    static let newMail = "⌘N"        // 新規メール作成
    static let reply = "⌘R"          // 返信
    static let replyAll = "⇧⌘R"      // 全員に返信
    static let forward = "⇧⌘F"       // 転送
    static let send = "⇧⌘D"          // 送信
    static let delete = "⌫"          // ゴミ箱へ
    static let search = "⌘F"         // 検索（ローカルのみ）
    static let preview = "Space"     // プレビュー切り替え
}
```

### アクセシビリティ必須要件
```swift
// VoiceOver対応は全UI要素で必須
messageCell.accessibilityLabel = "\(message.sender), \(message.subject)"
messageCell.accessibilityTraits = message.isRead ? .none : .updatesFrequently
messageCell.accessibilityHint = "ダブルタップでメールを開きます"

// キーボードナビゲーション完全対応
override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case 125: // 下矢印
        selectNextMessage()
    case 126: // 上矢印
        selectPreviousMessage()
    default:
        super.keyDown(with: event)
    }
}
```

## HTMLメール処理ポリシー

### セキュリティファースト原則
```swift
import WebKit

class SecureMailViewer {
    private func configureWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // JavaScript実行を完全禁止
        configuration.preferences.javaScriptEnabled = false
        
        // 永続データストアを使用しない
        configuration.websiteDataStore = .nonPersistent()
        
        // 外部リソースの自動読み込みを無効化
        configuration.suppressesIncrementalRendering = true
        
        return WKWebView(frame: .zero, configuration: configuration)
    }
    
    private func sanitizeHTML(_ html: String) -> String {
        // Content Security Policy適用
        let cspHeader = "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'self'; script-src 'none'; style-src 'unsafe-inline';\">"
        return cspHeader + html
    }
}
```

## セキュリティ実装要件

### 認証情報の取り扱い
```swift
// 必須: Keychainでのパスワード保存
import Security

func savePassword(_ password: String, for account: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecValueData as String: password.data(using: .utf8)!,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    SecItemAdd(query as CFDictionary, nil)
}

// 禁止: UserDefaultsやplistでの機密情報保存
```

### 通信セキュリティ
```swift
// 必須: TLS 1.2以上の強制
let session = URLSession(configuration: {
    let config = URLSessionConfiguration.default
    config.tlsMinimumSupportedProtocolVersion = .TLSv12
    return config
}())

// 必須: 証明書ピンニング（オプション）
func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) {
    // 証明書検証ロジック
}
```

## エラーハンドリング規約

### 独自エラー型の定義
```swift
enum MailError: LocalizedError {
    case connectionFailed(String)
    case authenticationFailed
    case invalidEmailFormat
    case networkTimeout
    case serverNotResponding
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let server):
            return "サーバー '\(server)' への接続に失敗しました"
        case .authenticationFailed:
            return "認証に失敗しました"
        case .invalidEmailFormat:
            return "メールアドレスの形式が正しくありません"
        case .networkTimeout:
            return "ネットワークタイムアウト"
        case .serverNotResponding:
            return "サーバーが応答していません"
        case .quotaExceeded:
            return "メールボックスの容量制限を超えています"
        }
    }
}
```

### エラーリカバリー戦略
```swift
struct RetryPolicy {
    static let maxRetries = 3
    static let backoffMultiplier = 2.0
    static let initialDelay: TimeInterval = 1.0
    
    static func retry<T>(
        operation: @escaping () async throws -> T,
        policy: RetryPolicy = RetryPolicy()
    ) async throws -> T {
        var lastError: Error?
        var delay = initialDelay
        
        for _ in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay *= backoffMultiplier
            }
        }
        
        throw lastError ?? MailError.serverNotResponding
    }
}
```

### オフライン時の動作
```swift
class OfflineQueue {
    // 送信: ローカルキューに保存
    func queueForSending(_ message: Message) {
        outboxQueue.append(message)
        NotificationCenter.default.post(name: .mailQueuedForSending, object: message)
    }
    
    // 接続回復時に自動送信
    func processQueuedMessages() {
        for message in outboxQueue {
            sendMessage(message)
        }
    }
}
```

## パフォーマンス実装指針

### 非同期処理
```swift
// メインスレッド以外での重い処理
DispatchQueue.global(qos: .userInitiated).async {
    let messages = self.parseMessages(data)
    
    DispatchQueue.main.async {
        self.displayMessages(messages)
    }
}

// バックグラウンド処理の優先度設定
// .userInteractive: UI更新（避ける）
// .userInitiated: ユーザーが待っている処理
// .utility: バックグラウンド同期など
// .background: インデックス作成など
```

### メモリ効率化
```swift
// 画像の遅延読み込み
lazy var avatarImage: NSImage? = {
    return loadAvatar()
}()

// 大量データの処理では autoreleasepoolを使用
autoreleasepool {
    for message in largeMessageArray {
        processMessage(message)
    }
}

// 不要なキャッシュの定期削除
Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
    self.purgeOldCache()
}
```

## ユーザー設定（最小限）

### 必須設定
- アカウント情報（メールアドレス、パスワード、サーバー設定）
- 署名テキスト
- 同期間隔（手動/5分/15分/30分）

### オプション設定
- フォントサイズ（小/標準/大）
- ダークモード対応（システム設定に従う）
- 通知設定（オン/オフ）
- 起動時の動作（前回終了時の状態を復元/受信箱を表示）

### 設定画面実装方針
```swift
// シンプルな2階層まで
// 第1階層: 一般、アカウント、詳細
// 第2階層: 各カテゴリの設定項目
// 高度な設定は隠す（必要な人だけが見つけられる）
```

## 機能実装の優先順位

### Phase 1: 基盤 (最優先)
- [ ] AppDelegate, MainWindowController
- [ ] 基本的な3ペインレイアウト
- [ ] アカウント設定UI
- [ ] データモデル (Account, Message, Folder)
- [ ] Keychainアクセス層

### Phase 2: 受信機能
- [ ] IMAP接続クラス
- [ ] POP3接続クラス
- [ ] メッセージパーサー
- [ ] メッセージ一覧表示
- [ ] メッセージ詳細表示（プレーンテキスト優先）
- [ ] HTMLメール表示（セキュア設定）

### Phase 3: 送信機能
- [ ] SMTP接続クラス
- [ ] メール作成UI
- [ ] 送信処理
- [ ] 下書き保存
- [ ] 送信キュー管理

### Phase 4: 基本機能強化
- [ ] ローカル検索
- [ ] キーボードショートカット完全実装
- [ ] アクセシビリティ対応
- [ ] 添付ファイル処理

### Phase 5: 最適化
- [ ] パフォーマンス改善
- [ ] エラーハンドリング強化
- [ ] メモリ使用量最適化
- [ ] 起動時間短縮

## 実装時の注意事項

### 避けるべき実装
```swift
// ❌ 避ける: 巨大なViewControllerクラス
class MassiveViewController: NSViewController {
    // 500行以上のコード...
}

// ✅ 好ましい: 責任を分割
class MailListViewController: NSViewController {
    private let dataSource = MailListDataSource()
    private let delegate = MailListDelegate()
    private let layoutManager = MailListLayoutManager()
}

// ❌ 避ける: 同期的なネットワーク処理
let data = try Data(contentsOf: url)

// ✅ 好ましい: 非同期処理
Task {
    let data = try await URLSession.shared.data(from: url)
}
```

### ログ出力の指針
```swift
// 開発時のみ: os_logを使用
import os.log

private let logger = OSLog(subsystem: "com.swiftmail.app", category: "MailService")

func logInfo(_ message: String) {
    #if DEBUG
    os_log("%{public}@", log: logger, type: .info, message)
    #endif
}

func logError(_ error: Error) {
    #if DEBUG
    os_log("%{public}@", log: logger, type: .error, String(describing: error))
    #endif
}
```

## テスト戦略

### ユニットテスト対象
- [ ] Models (Message, Account parsing)
- [ ] Services (IMAP, SMTP connection logic)
- [ ] Repositories (data persistence logic)
- [ ] Utilities (Date formatting, String helpers)

### 統合テスト対象
- [ ] メール送受信フロー
- [ ] オフライン→オンライン切り替え
- [ ] キャッシュ同期

### テスト除外対象
- UI Controllers (手動テストで対応)
- サードパーティサービス連携

### テストコード例
```swift
class MessageParserTests: XCTestCase {
    func testParseSimpleMessage() {
        // Arrange
        let rawMessage = "From: test@example.com\r\nSubject: Test\r\n\r\nBody"
        
        // Act
        let message = MessageParser.parse(rawMessage)
        
        // Assert
        XCTAssertEqual(message.from, "test@example.com")
        XCTAssertEqual(message.subject, "Test")
        XCTAssertEqual(message.body, "Body")
    }
    
    func testParseMultipartMessage() async {
        // 非同期テストの例
        let result = await MessageParser.parseMultipart(complexMessage)
        XCTAssertEqual(result.parts.count, 2)
    }
}
```

## 開発環境設定

### 必要なXcode設定
- Swift Language Version: 5.9
- Deployment Target: macOS 12.0
- App Sandbox: Enabled
- Network Outgoing: Enabled
- Keychain Access Groups: 設定
- Hardened Runtime: Enabled

### ビルド構成
```
Debug: 詳細なログ出力、アサーション有効、最適化なし
Release: 最適化有効、ログ出力最小限、dSYM生成
Profile: Instruments向け、最適化有効、デバッグシンボル付き
```

### 必要なEntitlements
```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.swiftmail.app</string>
</array>
```

## Claude Codeでの開発時の指示

### コード生成時の優先事項
1. **軽量性**: 機能よりもパフォーマンスを優先
2. **読みやすさ**: 将来の拡張を考慮したクリーンなコード
3. **macOSネイティブ**: Appleの設計思想に準拠
4. **セキュリティ**: 認証情報の適切な取り扱い
5. **最小限主義**: 本当に必要な機能だけを実装

### レビュー観点チェックリスト
- [ ] メモリリークの可能性はないか
- [ ] UI更新がメインスレッドで実行されているか
- [ ] エラーハンドリングが適切か
- [ ] ファイル構成が規約に従っているか
- [ ] 機能が最小限に絞られているか
- [ ] パフォーマンス目標を満たしているか
- [ ] アクセシビリティ対応がされているか
- [ ] セキュリティベストプラクティスに従っているか

### 開発時の判断基準
```
新機能追加の判断フロー:
1. その機能はメールの送受信に必須か？
   → No: 実装しない
   → Yes: 次へ
2. 既存の機能で代替可能か？
   → Yes: 実装しない
   → No: 次へ
3. パフォーマンスに悪影響はないか？
   → Yes: 実装しない
   → No: 最小限の実装を検討
```

## バージョン管理方針

### セマンティックバージョニング
- Major: 互換性のない変更
- Minor: 後方互換性のある機能追加
- Patch: バグ修正

### リリースサイクル
- バグ修正: 随時
- 機能追加: 慎重に検討（本当に必要な場合のみ）
- メジャーアップデート: 年1回以下