import AppKit
#if TARGET_INTERFACE_BUILDER

@MainActor
protocol FolderListViewControllerDelegate: AnyObject {}

@MainActor
final class FolderListViewController: NSViewController {
    weak var delegate: FolderListViewControllerDelegate?
}

#else

import SwiftMailCore

@MainActor
protocol FolderListViewControllerDelegate: AnyObject {
    func folderListViewController(_ controller: FolderListViewController, didSelect folder: IMAPFolder?)
}

@MainActor
final class FolderListViewController: NSViewController {
    weak var delegate: FolderListViewControllerDelegate?

    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var scrollView: NSScrollView!
    @IBOutlet private weak var placeholderLabel: NSTextField!

    private var folders: [IMAPFolder] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        scrollView.drawsBackground = false
        updatePlaceholderVisibility()
    }

    func updateFolders(_ folders: [IMAPFolder]) {
        self.folders = folders
        tableView.reloadData()
        if folders.isEmpty {
            placeholderLabel.stringValue = "フォルダーがありません"
        }
        updatePlaceholderVisibility()
    }

    func showPlaceholder(text: String) {
        placeholderLabel.stringValue = text
        folders = []
        tableView.reloadData()
        updatePlaceholderVisibility()
    }

    func selectFolder(withID id: String?) {
        guard let id, let row = folders.firstIndex(where: { $0.id == id }) else {
            tableView.deselectAll(nil)
            return
        }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    private func configureTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.selectionHighlightStyle = .regular
        tableView.allowsEmptySelection = true
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.headerView = nil
        tableView.columnAutoresizingStyle = .lastColumnOnly
        tableView.rowHeight = 36
    }

    private func updatePlaceholderVisibility() {
        let isEmpty = folders.isEmpty
        placeholderLabel.isHidden = !isEmpty
        scrollView.isHidden = isEmpty
    }
}

extension FolderListViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        folders.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < folders.count else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("FolderCell")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            textField.textColor = NSColor.labelColor
            cell.textField = textField
            cell.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        cell.textField?.stringValue = folders[row].name
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < folders.count {
            delegate?.folderListViewController(self, didSelect: folders[selectedRow])
        } else {
            delegate?.folderListViewController(self, didSelect: nil)
        }
    }
}

#endif
