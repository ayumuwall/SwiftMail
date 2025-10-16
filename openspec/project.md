# Project Context

## Purpose
SwiftMailは、macOS専用で「高速・軽量・集中できる」体験を追求するメールクライアントです。Mail.app互換の操作性を維持しつつ、1秒未満で起動し、数千通のメールを瞬時に検索できることを目標に、プライバシー保護とオフライン動作を最優先に設計されています。

## Tech Stack
- Swift 6（Swift Package Manager構成）
- AppKit / Foundation / Security（macOS 12.0以上）
- SQLite3 C API（FTS5有効）によるローカルストレージ
- XCTestによるユニットテスト／統合テスト

## Project Conventions

### Code Style
Swift APIデザインガイドラインに準拠し、値型と明示的な命名を重視します。1ファイル1責務（概ね200行以内）を目指し、AppKitで必要な場合を除き`class`継承は避けます。置換可能性を担保するためプロトコル主導で設計し、外部ライブラリやコード生成は導入しません（標準SwiftPMターゲットとシステムフレームワークのみ）。

### Architecture Patterns
3層構成を採用します。`SwiftMailCore`にドメインモデル・ポリシー・プロトコルを集約し、`SwiftMailDatabase`でSQLiteベースのリポジトリとFTS検索を実装、`SwiftMailApp`がAppKitエントリーポイントとUI層を担当します。永続化は`MailRepository`抽象を経由し、非同期処理はSwift Concurrency（async/await）と明示的なリトライポリシーで制御します。

### Testing Strategy
モジュールごとにXCTestターゲット（`SwiftMailCoreTests` / `SwiftMailDatabaseTests`）を用意し、ドメインロジック、Keychain連携、メッセージの構築・解析、データベース永続化をカバーします。新しい振る舞いを追加する際は、対象モジュールのユニットテストと必要に応じた統合テスト（ディスクI/Oや非同期処理）を追加します。AppKit UIは安定前のため手動テストが前提です。

### Git Workflow
`main`ブランチを唯一のトランクとし、作業は短命な`feature/...`ブランチで行います。コミットは小さく説明的にまとめ、マージ前にPull Requestでレビューします。新機能は事前議論と承認済みの提案が必須で、性能改善・バグ修正・セキュリティ強化は迅速なレビューを優先します。外部依存の追加は禁止です。

## Domain Context
SwiftMailはIMAP/POP3による受信、SMTPによる送信、フォルダー操作など伝統的なメールワークフローに専念します。カレンダー、タスク管理、AI機能などは対象外です。全メールをローカルにキャッシュしてオフライン動作を保証し、操作は後追いで同期キューに蓄積します。キーボードショートカットはMail.app準拠とし、プライバシー保護のためリモートコンテンツを既定で無効化、RFC 822/2047のエンコード規約を順守します。

## Important Constraints
- 外部ライブラリや外部サービスを使用せず、macOS標準フレームワークと同梱SQLiteのみを利用すること。
- パフォーマンス目標：コールドスタート1秒未満、1万通検索10ms程度、1,000通でメモリ100MB以下。
- セキュリティ要件：資格情報はKeychainに保存し、TLS 1.2以上を強制、メッセージレンダリング時のスクリプト・外部リソースを遮断すること。
- 対応OSはmacOS 12.0以上とし、UIはAppKitで構築（SwiftUIは現時点で対象外）。

## External Dependencies
- macOSシステムフレームワーク（AppKit / Foundation / Security / Network）
- macOSに同梱されるSQLite3（FTS5対応）
- IMAP / POP3 / SMTPプロトコルに準拠したメールサーバー
