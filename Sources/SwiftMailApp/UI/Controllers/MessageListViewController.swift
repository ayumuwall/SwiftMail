import AppKit
#if TARGET_INTERFACE_BUILDER

@MainActor
protocol MessageListViewControllerDelegate: AnyObject {}

@MainActor
final class MessageListViewController: NSViewController {
    weak var delegate: MessageListViewControllerDelegate?
}

#else

import SwiftMailCore

@MainActor
protocol MessageListViewControllerDelegate: AnyObject {
    func messageListViewController(_ controller: MessageListViewController, didSelect message: Message?)
}

@MainActor
final class MessageListViewController: NSViewController {
    weak var delegate: MessageListViewControllerDelegate?

    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var scrollView: NSScrollView!
    @IBOutlet private weak var placeholderLabel: NSTextField!

    private var messages: [Message] = []
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        scrollView.drawsBackground = false
        updatePlaceholderVisibility()
    }

    func showPlaceholder(text: String) {
        placeholderLabel.stringValue = text
        messages = []
        tableView.reloadData()
        updatePlaceholderVisibility()
    }

    func updateMessages(_ messages: [Message]) {
        self.messages = messages
        tableView.reloadData()
        if messages.isEmpty {
            placeholderLabel.stringValue = "メッセージがありません"
        }
        updatePlaceholderVisibility()
    }

    func setLoadingState() {
        placeholderLabel.stringValue = "メッセージを読み込み中…"
        messages = []
        tableView.reloadData()
        updatePlaceholderVisibility()
    }

    func selectMessage(withID id: String?) {
        guard let id, let row = messages.firstIndex(where: { $0.id == id }) else {
            tableView.deselectAll(nil)
            return
        }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    private func configureTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.selectionHighlightStyle = .regular
        tableView.rowHeight = 56
        tableView.columnAutoresizingStyle = .lastColumnOnly
        adjustColumnSizing()
    }

    private func adjustColumnSizing() {
        if let senderColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("sender")) {
            senderColumn.minWidth = 120
            senderColumn.width = 180
        }
        if let subjectColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("subject")) {
            subjectColumn.minWidth = 260
        }
        if let dateColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("date")) {
            dateColumn.minWidth = 100
            dateColumn.maxWidth = 160
            dateColumn.width = 140
        }
    }

    private func updatePlaceholderVisibility() {
        let isEmpty = messages.isEmpty
        placeholderLabel.isHidden = !isEmpty
        scrollView.isHidden = isEmpty
    }
}

extension MessageListViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        messages.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < messages.count, let identifier = tableColumn?.identifier else { return nil }
        let message = messages[row]
        let cellIdentifier = NSUserInterfaceItemIdentifier("MessageCell-\(identifier.rawValue)")

        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellIdentifier

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            textField.font = identifier.rawValue == "subject"
                ? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                : NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            textField.textColor = identifier.rawValue == "subject"
                ? NSColor.labelColor
                : NSColor.secondaryLabelColor
            cell.textField = textField
            cell.addSubview(textField)

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        switch identifier.rawValue {
        case "sender":
            if let sender = message.sender {
                cell.textField?.stringValue = sender.name?.isEmpty == false ? sender.name! : sender.email
            } else {
                cell.textField?.stringValue = ""
            }
        case "subject":
            cell.textField?.stringValue = message.subject ?? "(件名なし)"
        case "date":
            if let date = message.date {
                cell.textField?.stringValue = Self.dateFormatter.string(from: date)
            } else {
                cell.textField?.stringValue = ""
            }
        default:
            cell.textField?.stringValue = ""
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < messages.count {
            delegate?.messageListViewController(self, didSelect: messages[selectedRow])
        } else {
            delegate?.messageListViewController(self, didSelect: nil)
        }
    }
}

#endif
