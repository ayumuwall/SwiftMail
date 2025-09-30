import AppKit

final class MessageListViewController: NSViewController {
    @IBOutlet private weak var tableView: NSTableView?

    private let dataSource = MessageListDataSource()

    override func viewDidLoad() {
        super.viewDidLoad()
        if tableView == nil {
            tableView = locateTableView(in: view)
        }
        tableView?.dataSource = dataSource
        tableView?.delegate = dataSource
        tableView?.reloadData()
        tableView?.target = self
        tableView?.action = #selector(didSelectRow)
    }

    @objc private func didSelectRow() {
        // 選択変更時の通知ポイント。今後詳細ペインとの連携に使用。
    }

    private func locateTableView(in view: NSView) -> NSTableView? {
        if let tableView = view as? NSTableView {
            return tableView
        }
        for subview in view.subviews {
            if let tableView = locateTableView(in: subview) {
                return tableView
            }
        }
        return nil
    }
}

private final class MessageListDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private struct Row {
        let subject: String
        let sender: String
        let preview: String
        let date: Date
    }

    private let rows: [Row] = [
        Row(subject: "SwiftMail へようこそ", sender: "SwiftMail Team", preview: "SwiftMail の開発を始めましょう。", date: Date())
    ]

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("MessageListCell")
        let view = tableView.makeView(withIdentifier: identifier, owner: nil) as? MessageListCellView ?? MessageListCellView()

        guard row < rows.count else {
            return view
        }

        let model = rows[row]
        view.textField?.stringValue = model.subject
        view.subtitleLabel.stringValue = "\(model.sender) – \(model.preview)"

        return view
    }
}

private final class MessageListCellView: NSTableCellView {
    let subtitleLabel: NSTextField

    override init(frame frameRect: NSRect) {
        subtitleLabel = NSTextField(labelWithString: "")
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        subtitleLabel = NSTextField(labelWithString: "")
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        identifier = NSUserInterfaceItemIdentifier("MessageListCell")

        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize + 1, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.lineBreakMode = .byTruncatingTail

        let stackView = NSStackView(views: [titleLabel, subtitleLabel])
        stackView.orientation = .vertical
        stackView.spacing = 2
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])

        textField = titleLabel
    }
}
