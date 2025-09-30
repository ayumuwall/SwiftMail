import AppKit

final class MainSplitViewController: NSSplitViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        splitView.isVertical = true
        splitView.dividerStyle = .thin

        if splitViewItems.count >= 3 {
            splitViewItems[0].minimumThickness = 180
            splitViewItems[1].minimumThickness = 320
            splitViewItems[2].minimumThickness = 360
            splitViewItems[2].canCollapse = false
        }
    }
}
