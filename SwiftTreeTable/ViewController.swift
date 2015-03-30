import UIKit

class ViewController: UITableViewController, IMGTreeControllerDelegate {
    
    var tree: IMGTree!
    var controller: IMGTreeController!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let construction = IMGSampleTreeConstructor()
        tree = construction.sampleCommentTree()
        
        controller = IMGTreeController(tableView: tableView, delegate: self)
        
        
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        controller.tree = tree
    }
    
    func cell(node: IMGTreeNode, indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as UITableViewCell
        switch node {
        case is IMGCommentNode:
            let commentNode = node as IMGCommentNode
            cell.textLabel?.text = commentNode.comment
        case is IMGTreeSelectionNode:
            cell.textLabel?.text = "selection"
            cell.accessoryType = UITableViewCellAccessoryType.DetailButton
        case is IMGTreeActionNode:
            cell.textLabel?.text = "action"
            cell.accessoryType = UITableViewCellAccessoryType.DetailButton
        default:
            break
        }
        return cell
    }
    
    func collapsedCell(node: IMGTreeNode, indexPath: NSIndexPath) -> UITableViewCell {
        return cell(node, indexPath: indexPath)
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        controller.didSelectRow(indexPath)
    }
    
    override func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
        controller.didTriggerActionFromIndex(indexPath)
    }
}

