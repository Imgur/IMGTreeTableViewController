import UIKit
import IMGTreeTableView

class ViewController: UIViewController, IMGTreeTableControllerDelegate, UITableViewDelegate {
    
    var tree: IMGTree!
    var controller: IMGTreeTableController!
    
    @IBOutlet var tableView: UITableView!
    
    let backgroundColors = [UIColor.turquoiseColor(), UIColor.greenSeaColor(), UIColor.emeraldColor(), UIColor.nephritisColor(), UIColor.peterRiverColor(), UIColor.belizeHoleColor(), UIColor.amethystColor(), UIColor.wisteriaColor(), UIColor.wetAsphaltColor(), UIColor.midnightBlueColor()]
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .greenSeaColor()
        tableView.delegate = self
        tableView.tintColor = UIColor.whiteColor()
        view.backgroundColor = .greenSeaColor()
        
        let construction = IMGSampleTreeConstructor()
        tree = construction.sampleCommentTree()
        controller = IMGTreeTableController(tableView: tableView, delegate: self)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        controller.tree = tree
    }
    
    // MARK: IMGTreeTableControllerDelegate
    
    func cell(node: IMGTreeNode, indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! UITableViewCell
        switch node {
        case let commentNode as IMGCommentNode:
            cell.textLabel?.text = commentNode.comment
            cell.accessoryType = .None
        case is IMGTreeSelectionNode:
            cell.textLabel?.text = "selection"
            cell.accessoryType = .DetailButton
        case is IMGTreeActionNode:
            cell.textLabel?.text = "action"
            cell.accessoryType = .DetailButton
        case is IMGTreeCollapsedSectionNode:
            cell.textLabel?.text = "collapsed"
            cell.accessoryType = .None
        default:
            break
        }
        cell.backgroundColor = backgroundColors[(node.depth) % backgroundColors.count]
        cell.textLabel?.textColor = UIColor.cloudsColor()
        cell.selectionStyle = .None
        return cell
    }
    
    // MARK: UITableViewDelegate

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        controller.didSelectRow(indexPath)
    }
    
    func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
        controller.didTriggerActionFromIndex(indexPath)
    }
}

