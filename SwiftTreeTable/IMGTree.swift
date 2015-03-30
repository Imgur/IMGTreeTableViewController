import UIKit

protocol IMGTreeConstructorDelegate : class {
    func childrenForNodeObject(object: AnyObject) -> [AnyObject]?
    func configureNode(node: IMGTreeNode, modelObject: AnyObject)
    func classForNode() -> IMGTreeNode.Type
}

@objc(IMGTree)
class IMGTree: NSObject, NSCoding {
    
    let rootNode:IMGTreeNode
    
    override init() {
        rootNode = IMGTreeNode()
    }
    
    //MARK: tree construction class methods
    
    class func tree(fromRootArray rootArray: [AnyObject], withConstructerDelegate constructorDelegate: IMGTreeConstructorDelegate) -> IMGTree
    {
        let tree = IMGTree()
        let nodeClass = constructorDelegate.classForNode()
        var childNodes: [IMGTreeNode] = []
        
        for rootObject in rootArray {
            let rootNode = nodeClass(parentNode: tree.rootNode)
            constructorDelegate.configureNode(rootNode, modelObject: rootObject)
            if let childObjects = constructorDelegate.childrenForNodeObject(rootObject) {
                rootNode.children = IMGTree.process(tree.rootNode, childObjects: childObjects, tree: tree, constructorDelegate: constructorDelegate) as [IMGTreeNode]
            }
            childNodes.append(rootNode)
        }
        
        if !childNodes.isEmpty {
            tree.rootNode.children = childNodes
        }
        return tree
    }
    
    private class func process(parentNode: IMGTreeNode, childObjects: [AnyObject], tree: IMGTree, constructorDelegate: IMGTreeConstructorDelegate) -> [AnyObject]? {
        
        let nodeClass = constructorDelegate.classForNode()
        var childNodes: [IMGTreeNode] = []
        for childObject in childObjects {
            let childNode = nodeClass(parentNode: parentNode)
            constructorDelegate.configureNode(childNode, modelObject: childObject)
            if let childObjects = constructorDelegate.childrenForNodeObject(childObject) {
                childNode.children = IMGTree.process(tree.rootNode, childObjects: childObjects, tree: tree, constructorDelegate: constructorDelegate) as [IMGTreeNode]
            }
            childNodes.append(childNode)
        }
        
        return childNodes
    }
    
    //MARK: NSCoding
 
    required convenience init(coder aDecoder: NSCoder) {
        self.init()
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        
    }
    
    //MARK: DebugPrintable
    
    override var description : String {
        var tableState = "Tree: rootnode: \(rootNode.description)\n"

        for node in rootNode.infixTraversal() {
            tableState += "\(node.description)\n"
        }

        return tableState
    }
}

class IMGTreeNode: NSObject, NSCoding, NSCopying {
    
    weak var parentNode: IMGTreeNode?
    var children: [IMGTreeNode] {
        didSet {
            children = children.map({ (var node: IMGTreeNode) -> IMGTreeNode in
                node.parentNode = self
                return node
            })
        }
    }
    
    var isSelected: Bool {
        get {
            for node in children {
                if node.isKindOfClass(IMGTreeSelectionNode) {
                    return true
                }
            }
            return false
        }
    }
    var depth: Int {
        var currentNode: IMGTreeNode = self
        var depth = 0
        
        while currentNode.parentNode != nil {
            currentNode = currentNode.parentNode!
            depth++
        }
        
        return depth
    }
    var isChildrenVisible: Bool {
        get {
            if children.count > 0{
                if children.first!.isKindOfClass(IMGTreeSelectionNode) {
                    if children.count > 1 {
                        return children[1].isVisible
                    } else {
                        return false
                    }
                } else {
                    return children[0].isVisible
                }
            }
            return false
        }
    }
    var rootNode: IMGTreeNode {
        get {
            var currentNode: IMGTreeNode = self
            
            while currentNode.parentNode != nil {
                currentNode = currentNode.parentNode!
            }
            
            return currentNode
        }
    }
    var isVisible: Bool {
        willSet {
            previousVisibleIndex = visibleTraversalIndex()
            if isVisible {
                
                previousVisibleChildren = indicesForTraversal()
            } else {
                previousVisibleChildren = []
            }
        }
        didSet {
            if isVisible != oldValue {
                NSNotificationCenter.defaultCenter().postNotificationName("isVisibleChanged", object: self)
            }
        }
    }
    var previousVisibleIndex: Int?
    var previousVisibleChildren: [NSIndexPath]?
    
    //MARK: Initializers
    
    override init() {
        isVisible = false
        children = []
    }
    
    required init (parentNode nodesParent: IMGTreeNode) {
        isVisible = false
        parentNode = nodesParent
        children = []
    }
    
    //MARK: NSCoding
    
    required convenience init(coder aDecoder: NSCoder) {
        self.init()
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        
    }
    
    //MARK: Public
    
    func addChild(child: IMGTreeNode) {
        if child.isKindOfClass(IMGTreeSelectionNode) {
            children.insert(child, atIndex: 0)
            child.parentNode = self
        } else {
            children += [child]
        }
    }
    
    func removeChild(child: IMGTreeNode) {
        if let targetIndex = find(children, child) {
            children.removeAtIndex(targetIndex)
        }
    }
    
    func removeFromParent() {
        isVisible = false
        parentNode?.removeChild(self)
    }
    
    func hasSelectionNode() -> Bool {
        return findChildNode(IMGTreeSelectionNode) != nil
    }
    
    func hasActionNode() -> Bool {
        return findChildNode(IMGTreeActionNode) != nil
    }
    
    func indexForNode(node: IMGTreeNode) -> Int? {
        var traversal = infixTraversal(visible: false)
        return find(traversal, node)
    }
    
    func visibleIndexForNode(node: IMGTreeNode) -> Int? {
        var traversal = infixTraversal()
        return find(traversal, node)
    }
    
    func visibleTraversalCount() -> Int {
        return infixTraversal().count ?? 0
    }
    
    func traversalCount() -> Int {
        return infixTraversal(visible: false).count ?? 0
    }
    
    func visibleNodeForIndex(index: Int) -> IMGTreeNode? {
        let traversal = rootNode.infixTraversal()
        return traversal[index] ?? nil
    }
    
    func visibleTraversalIndex() -> Int? {
        return rootNode.visibleIndexForNode(self)
    }
    
    func indicesForTraversal() -> [NSIndexPath] {
        let traversal = infixTraversal()
        return traversal.map({ (node: IMGTreeNode) -> NSIndexPath in
            return NSIndexPath(forRow: node.visibleTraversalIndex()!, inSection: 0)
        })
    }
    
    func isSelectionNodeInVisibleTraversal() -> Bool {
        let traversal = infixTraversal()
        for node in traversal {
            if node.isKindOfClass(IMGTreeSelectionNode) {
                return true
            }
        }
        return false
    }
    
    //MARK: Private
    
    private func traversalIndex() -> Int? {
        return rootNode.indexForNode(self)
    }
    
    private func infixTraversal(visible: Bool = true) -> [IMGTreeNode] {
        
        var traversal = { (childNodes: [IMGTreeNode]) -> [IMGTreeNode] in
            var traversal: [IMGTreeNode] = []
            for node in childNodes {
                traversal.append(node)
                traversal.extend(node.infixTraversal(visible: visible))
            }
            
            return traversal
        }
        
        if visible {
            var childNodes = children.filter({ (node: IMGTreeNode) -> Bool in
                return node.isVisible
            })
            return traversal(childNodes)
        } else {
            return traversal(children)
        }
    }
    
    private func findChildNode(ofClass: AnyClass) -> IMGTreeNode? {
        let filtered = children.filter({ (node) -> Bool in
            return node.isKindOfClass(ofClass)
        })
        
        return filtered.first
    }
    
    //MARK: DebugPrintable
    
    override var description : String {
        return "Node: \(rootNode.indexForNode(self)) \n"
    }
    
    //MARK: NSCopying
    
    func copyWithZone(zone: NSZone) -> AnyObject {
        let nodeCopy = IMGTreeNode()
        nodeCopy.parentNode = parentNode
        nodeCopy.children = children
        nodeCopy.isVisible = isVisible
        return nodeCopy
    }
}

/**
Class for nodes that represent user 'selection' of a parent node
*/
class IMGTreeSelectionNode : IMGTreeNode {

}

class IMGTreeActionNode : IMGTreeNode {

}

class IMGTreeCollapsedSectionNode : IMGTreeNode {
    
}