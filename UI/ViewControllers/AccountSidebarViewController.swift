import AppKit

final class AccountSidebarViewController: NSViewController {
    @IBOutlet private weak var outlineView: NSOutlineView?

    private let dataSource = SidebarDataSource()

    override func viewDidLoad() {
        super.viewDidLoad()
        if outlineView == nil {
            outlineView = locateOutlineView(in: view)
        }
        outlineView?.dataSource = dataSource
        outlineView?.delegate = dataSource
        outlineView?.reloadData()
    }

    private func locateOutlineView(in view: NSView) -> NSOutlineView? {
        if let outline = view as? NSOutlineView {
            return outline
        }
        for subview in view.subviews {
            if let outline = locateOutlineView(in: subview) {
                return outline
            }
        }
        return nil
    }
}

private final class SidebarDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private struct Section {
        let title: String
        let children: [Item]
    }

    private struct Item {
        let identifier: String
        let title: String
    }

    private let sections: [Section] = [
        Section(title: "アカウント", children: [
            Item(identifier: "sample-account", title: "アカウントを追加…")
        ])
    ]

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let section = item as? Section {
            return section.children.count
        }
        return sections.count
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        item is Section
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let section = item as? Section {
            return section.children[index]
        }
        return sections[index]
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let viewIdentifier = NSUserInterfaceItemIdentifier("SidebarCell")
        let view = outlineView.makeView(withIdentifier: viewIdentifier, owner: nil) as? NSTableCellView ?? {
            let cell = NSTableCellView(frame: .zero)
            cell.identifier = viewIdentifier
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell.textField = textField
            cell.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell
        }()

        if let section = item as? Section {
            view.textField?.stringValue = section.title
            view.textField?.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        } else if let item = item as? Item {
            view.textField?.stringValue = item.title
            view.textField?.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        }
        return view
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        item is Section
    }
}
