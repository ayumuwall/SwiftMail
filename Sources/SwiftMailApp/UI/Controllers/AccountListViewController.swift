import AppKit
import SwiftMailCore

@MainActor
final class AccountListViewController: NSViewController {

    // MARK: - UI Components

    private lazy var tableView: NSTableView = {
        let table = NSTableView()
        table.style = .plain
        table.headerView = nil
        table.doubleAction = #selector(tableViewDoubleClicked)
        table.target = self
        return table
    }()

    private let scrollView = NSScrollView()

    private lazy var addButton: NSButton = {
        let button = NSButton(title: "追加", target: self, action: #selector(addButtonTapped))
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var editButton: NSButton = {
        let button = NSButton(title: "編集", target: self, action: #selector(editButtonTapped))
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false
        return button
    }()

    private lazy var deleteButton: NSButton = {
        let button = NSButton(title: "削除", target: self, action: #selector(deleteButtonTapped))
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false
        return button
    }()

    // MARK: - Properties

    private var accounts: [Account] = []
    var onAccountSelected: ((Account) -> Void)?
    var onAccountsChanged: (([Account]) -> Void)?

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureLayout()
        configureTableView()
    }

    // MARK: - Configuration

    private func configureLayout() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        let buttonStack = NSStackView(views: [addButton, editButton, deleteButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -8),

            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            buttonStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -8),
            buttonStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])
    }

    private func configureTableView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AccountColumn"))
        column.title = "アカウント"
        column.width = 200
        tableView.addTableColumn(column)

        tableView.dataSource = self
        tableView.delegate = self
    }

    // MARK: - Actions

    @objc private func addButtonTapped() {
        showAccountSettings(account: nil)
    }

    @objc private func editButtonTapped() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else { return }

        let account = accounts[selectedRow]
        showAccountSettings(account: account)
    }

    @objc private func deleteButtonTapped() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else { return }

        let account = accounts[selectedRow]

        let alert = NSAlert()
        alert.messageText = "アカウントを削除"
        alert.informativeText = "アカウント「\(account.email)」を削除しますか？この操作は取り消せません。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "削除")
        alert.addButton(withTitle: "キャンセル")

        if alert.runModal() == .alertFirstButtonReturn {
            accounts.remove(at: selectedRow)
            tableView.removeRows(at: IndexSet(integer: selectedRow), withAnimation: .slideUp)
            updateButtonStates()
            onAccountsChanged?(accounts)

            // Keychainからパスワードを削除
            let keychainManager = KeychainManager()
            try? keychainManager.deletePassword(for: account.id)
        }
    }

    @objc private func tableViewDoubleClicked() {
        guard tableView.clickedRow >= 0 else { return }
        editButtonTapped()
    }

    // MARK: - Helpers

    private func showAccountSettings(account: Account?) {
        let settingsVC = AccountSettingsViewController()

        if let account = account {
            settingsVC.setAccount(account)
        }

        settingsVC.onSave = { [weak self] savedAccount in
            guard let self = self else { return }

            if let existingIndex = self.accounts.firstIndex(where: { $0.id == savedAccount.id }) {
                self.accounts[existingIndex] = savedAccount
                self.tableView.reloadData(forRowIndexes: IndexSet(integer: existingIndex), columnIndexes: IndexSet(integer: 0))
            } else {
                self.accounts.append(savedAccount)
                self.tableView.insertRows(at: IndexSet(integer: self.accounts.count - 1), withAnimation: .slideDown)
            }

            self.updateButtonStates()
            self.onAccountsChanged?(self.accounts)
        }

        let window = NSWindow(contentViewController: settingsVC)
        window.title = account == nil ? "アカウント追加" : "アカウント編集"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 500, height: 600))
        window.center()
        window.makeKeyAndOrderFront(nil)

        NSApp.runModal(for: window)
        window.close()
    }

    private func updateButtonStates() {
        let hasSelection = tableView.selectedRow >= 0
        editButton.isEnabled = hasSelection
        deleteButton.isEnabled = hasSelection
    }

    // MARK: - Public API

    func setAccounts(_ accounts: [Account]) {
        self.accounts = accounts
        tableView.reloadData()
        updateButtonStates()
    }

    func getAccounts() -> [Account] {
        return accounts
    }
}

// MARK: - NSTableViewDataSource

extension AccountListViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return accounts.count
    }
}

// MARK: - NSTableViewDelegate

extension AccountListViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let account = accounts[row]

        let cellView = NSTableCellView()
        let textField = NSTextField(labelWithString: account.email)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingMiddle

        cellView.addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])

        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonStates()

        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 {
            let account = accounts[selectedRow]
            onAccountSelected?(account)
        }
    }
}
