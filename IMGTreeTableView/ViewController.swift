import UIKit

class ViewController: UIViewController, IMGTreeTableControllerDelegate, UITableViewDelegate {
    
    var tree: IMGTree!
    var controller: IMGTreeTableController!
    
    @IBOutlet var tableView: UITableView!
    
    let backgroundColors = [UIColor.whiteColor(), UIColor.turquoiseColor(), UIColor.greenSeaColor(), UIColor.emeraldColor(), UIColor.nephritisColor(), UIColor.peterRiverColor(), UIColor.belizeHoleColor(), UIColor.amethystColor(), UIColor.wisteriaColor(), UIColor.wetAsphaltColor()]

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .turquoiseColor()
        tableView.delegate = self
        view.backgroundColor = .turquoiseColor()
        
        let construction = IMGSampleTreeConstructor()
        tree = construction.sampleCommentTree()
        controller = IMGTreeTableController(tableView: tableView, delegate: self)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        controller.tree = tree
    }
    
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
    
    func collapsedCell(node: IMGTreeNode, indexPath: NSIndexPath) -> UITableViewCell {
        return cell(node, indexPath: indexPath)
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        controller.didSelectRow(indexPath)
    }
    
    func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
        controller.didTriggerActionFromIndex(indexPath)
    }
}

