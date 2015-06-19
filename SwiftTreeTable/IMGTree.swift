
import UIKit

/**
    This protocol allows a given class to fully configure an IMGTree instance with any given object graph
*/
@objc(IMGTreeConstructorDelegate)
protocol IMGTreeConstructorDelegate : class {
    /**
        For a given model object instance representing a node, return that objects children if any
    */
    func childrenForNodeObject(object: AnyObject) -> [AnyObject]?
    /**
        Configure a node for a given model object
    */
    func configureNode(node: IMGTreeNode, modelObject: AnyObject)
    /**
        Return the class type to be used as a node to contain the model object, eg. IMGCommentNode in the sample tree
    */
    func classForNode() -> IMGTreeNode.Type
}

/**
    Provides structure to a nested object graph such that it can be used in a UITableView or UICollectionView
*/
@objc(IMGTree)
class IMGTree: NSObject, NSCoding {
    
    /**
        Defines the root node which is never displayed on screen but contains the top level nodes
    */
    let rootNode:IMGTreeNode
    
    override init() {
        rootNode = IMGTreeNode()
    }
    
    //MARK: tree construction class methods
    
    /**
        Creates a new instance of IMGTree given the root level model objects and constructor object conforming to IMGTreeConstructorDelegate
    */
    class func tree(fromRootArray rootArray: [AnyObject], withConstructerDelegate constructorDelegate: IMGTreeConstructorDelegate) -> IMGTree
    {
        let tree = IMGTree()
        let nodeClass = constructorDelegate.classForNode()
        var childNodes: [IMGTreeNode] = []
        
        // go through each top level object creating the resulting node subtree for each one recursively with the process(:::) method
        for rootObject in rootArray {
            let rootNode = nodeClass(parentNode: tree.rootNode)
            constructorDelegate.configureNode(rootNode, modelObject: rootObject)
            if let childObjects = constructorDelegate.childrenForNodeObject(rootObject) {
                rootNode.children = IMGTree.process(tree.rootNode, childObjects: childObjects, tree: tree, constructorDelegate: constructorDelegate) as! [IMGTreeNode]
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
                childNode.children = IMGTree.process(tree.rootNode, childObjects: childObjects, tree: tree, constructorDelegate: constructorDelegate) as! [IMGTreeNode]
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
        //print readable string
        var tableState = "Tree: rootnode: \(rootNode.description)\n"
        
        for node in rootNode.infixTraversal() {
            tableState += "\(node.description)\n"
        }
        
        return tableState
    }
}

/**
    Represents an individual node which in turn represents a model object in a graph. Conforms to NSCopying in order to copy into subtree properties
*/
class IMGTreeNode: NSObject, NSCoding, NSCopying {
    
    /**
        The super node that owns this instance as part of it's children
    */
    weak var parentNode: IMGTreeNode?
    /**
        This node's children nodes
    */
    var children: [IMGTreeNode] {
        didSet {
            children = children.map({ (var node: IMGTreeNode) -> IMGTreeNode in
                node.parentNode = self
                return node
            })
        }
    }
    /**
        Is this node selected by the user?
    */
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
    /**
        The depth of this node in the treee as calculated by recursively calling the parent node.
    */
    var depth: Int {
        var currentNode: IMGTreeNode = self
        var depth = 0
        
        while currentNode.parentNode != nil {
            currentNode = currentNode.parentNode!
            depth++
        }
        
        return depth
    }
    /**
        The depth of this node up until the first collapsed section ancestor
    */
    var collapsedDepth: Int {
        var currentNode: IMGTreeNode = self
        var depth = 0
        
        while currentNode.parentNode != nil && !currentNode.parentNode!.isKindOfClass(IMGTreeCollapsedSectionNode) {
            currentNode = currentNode.parentNode!
            depth++
        }
        
        return depth
    }
    /**
        Is this node's children visible?
    */
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
    /**
        Find the nodes root node if it is attached to the tree
    */
    var rootNode: IMGTreeNode {
        get {
            var currentNode: IMGTreeNode = self
            
            while currentNode.parentNode != nil {
                currentNode = currentNode.parentNode!
            }
            
            return currentNode
        }
    }
    /**
        The anchor node represents the top node in its subtree which is usually the rootnode if the subtree has not been detached.
    */
    var anchorNode: IMGTreeNode {
        get {
            var currentNode: IMGTreeNode = self
            
            while currentNode.parentNode?.parentNode != nil {
                currentNode = currentNode.parentNode!
            }
            
            return currentNode
        }
    }
    
    var collapsedAnchorNode: IMGTreeNode {
        get {
            var currentNode: IMGTreeNode = self
            
            while currentNode.parentNode?.parentNode != nil && !currentNode.parentNode!.parentNode!.isKindOfClass(IMGTreeCollapsedSectionNode.self) {
                currentNode = currentNode.parentNode!
            }
            
            return currentNode
        }
    }
    /**
        Is the node visible within the tree?
    */
    var isVisible: Bool {
        willSet {
            //keep track of prior subtree visibility
            previousVisibleIndex = visibleTraversalIndex()
            if isVisible {
                
                previousVisibleChildren = visibleIndicesForTraversal()
            } else {
                previousVisibleChildren = []
            }
        }
        didSet {
            if isVisible != oldValue {
                //inform of change in visibility
                NSNotificationCenter.defaultCenter().postNotificationName("isVisibleChanged", object: self)
            }
        }
    }
    /**
        What was the nodes previous visible index before the start of the transaction
    */
    var previousVisibleIndex: Int?
    /**
        What was the nodes previous visible childrenw before the start of the transaction
    */
    var previousVisibleChildren: [NSIndexPath]?
    
    //MARK: Initializers
    
    override init() {
        isVisible = false
        children = []
    }
    
    /**
        Initialize under a parent node invisibily
    */
    required init (parentNode nodesParent: IMGTreeNode) {
        isVisible = false
        parentNode = nodesParent
        children = []
    }
    
    /**
        Initialize under a parent node setting visibility
    */
    required convenience init(parentNode: IMGTreeNode, isVisible: Bool) {
        self.init(parentNode: parentNode)
        self.isVisible = isVisible
    }
    
    //MARK: NSCoding
    
    required convenience init(coder aDecoder: NSCoder) {
        self.init()
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        
    }
    
    //MARK: Public
    
    /**
        Add the child node to the node as a child. If its a special node, it is inserted at the top.
    */
    func addChild(child: IMGTreeNode) {
        if child.isKindOfClass(IMGTreeSelectionNode) || child.isKindOfClass(IMGTreeCollapsedSectionNode) {
            children.insert(child, atIndex: 0)
        } else {
            children += [child]
        }
        child.parentNode = self
    }
    
    /**
        Remove a child.
    */
    func removeChild(child: IMGTreeNode) {
        if let targetIndex = find(children, child) {
            children.removeAtIndex(targetIndex)
        }
    }
    
    /**
        Removes this instance from its current parent node, effectively detaching from the tree
    */
    func removeFromParent() {
        isVisible = false
        parentNode?.removeChild(self)
    }
    /**
    Does this node have a selection node as a child
    */
    func selectionNodeInTraversal() -> IMGTreeSelectionNode? {
        return findTraversalNode(IMGTreeSelectionNode) as? IMGTreeSelectionNode
    }
    
    /**
    Does this node have an action node as a child
    */
    func actionNodeInTraversal() -> IMGTreeActionNode? {
        return findTraversalNode(IMGTreeActionNode) as? IMGTreeActionNode
    }
    
    /**
        Finds the location, if any, of the node with this instances children regardless of visibility
    */
    func indexForNode(node: IMGTreeNode) -> Int? {
        var traversal = infixTraversal(visible: false)
        return find(traversal, node)
    }
    
    /**
        Finds the location, if any, of the node with this instances visible children
    */
    func visibleIndexForNode(node: IMGTreeNode) -> Int? {
        var traversal = infixTraversal()
        return find(traversal, node)
    }
    
    /**
        Finds the number of visible child nodes
    */
    func visibleTraversalCount() -> Int {
        return infixTraversal().count ?? 0
    }
    
    /**
        Retrieves the visible node at the specified index, if any.
    */
    func visibleNodeForIndex(index: Int) -> IMGTreeNode? {
        let traversal = rootNode.infixTraversal()
        return traversal[index] ?? nil
    }
    
    /**
        Retrieves this instances index among the parents visible nodes, if any.
    */
    func visibleTraversalIndex() -> Int? {
        return rootNode.visibleIndexForNode(self)
    }
    
    /**
        Retrieves an array of indices of its visible children
    */
    func visibleIndicesForTraversal() -> [NSIndexPath] {
        let traversal = infixTraversal()
        return traversal.map({ (node: IMGTreeNode) -> NSIndexPath in
            return NSIndexPath(forRow: node.visibleTraversalIndex()!, inSection: 0)
        })
    }
    
    /**
        Does there exist a user selection within any of this nodes subtree
    */
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
    
    /**
        This instances index from the rootnode regardless of visibility.
    */
    private func traversalIndex() -> Int? {
        return rootNode.indexForNode(self)
    }
    
    /**
        The infix traversal of the subtree, visible or not
    */
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
    
    /**
        Finds a child node of the specificed class
    */
    private func findChildNode(ofClass: AnyClass) -> IMGTreeNode? {
        let filtered = children.filter({ (node) -> Bool in
            return node.isKindOfClass(ofClass)
        })
        
        return filtered.first
    }
    
    /**
        Finds a child node in the visible of the specificed class
    */
    private func findTraversalNode(ofClass: AnyClass) -> IMGTreeNode? {
        let traversal = infixTraversal()
        let filtered = traversal.filter({ (node) -> Bool in
            return node.isKindOfClass(ofClass)
        })
        
        return filtered.first
    }
    
    //MARK: DebugPrintable
    
    override var description : String {
        return "Node: \(rootNode.visibleIndexForNode(self)!) \n"
    }
    
    //MARK: NSCopying
    
    func copyWithZone(zone: NSZone) -> AnyObject {
        let nodeCopy = self.dynamicType(parentNode: parentNode!, isVisible: isVisible)
        nodeCopy.parentNode = parentNode
        nodeCopy.children = children.map({ (childNode: IMGTreeNode) -> IMGTreeNode in
            return childNode.copy() as! IMGTreeNode
        })
        return nodeCopy
    }
}

/**
    Class for nodes that represent user 'selection' of a parent node
*/
class IMGTreeSelectionNode : IMGTreeNode {
    
}

/**
    Class for nodes that represent actionables things on the parent
*/
class IMGTreeActionNode : IMGTreeNode {
    
}

/**
    Class for nodes that represent collapsed sections
*/
class IMGTreeCollapsedSectionNode : IMGTreeNode, NSCopying {
    
    /**
        The anchor or top level node this collapsed node is ancestor to
    */
    override var anchorNode: IMGTreeNode {
        return originatingNode.collapsedAnchorNode
    }
    /**
        The node that this node was triggered from
    */
    let originatingNode: IMGTreeNode
    /**
        The original anchors subtree
    */
    private let originalAnchorNode: IMGTreeNode
    
    var triggeredFromPreviousCollapsedSecton: Bool {
        if (parentNode != nil) {
            return originalAnchorNode.children.first!.isKindOfClass(IMGTreeCollapsedSectionNode)
        } else {
            return anchorNode.children.first!.isKindOfClass(IMGTreeCollapsedSectionNode)
        }
    }
    
    var indicesForContainingNodes: [NSIndexPath] {
        var rowsToHide: [NSIndexPath] = []
        
        rowsToHide.extend(originatingNode.visibleIndicesForTraversal())
        originatingNode.children.map({ (var child: IMGTreeNode) -> IMGTreeNode in
            child.isVisible = false
            return child
        })
        
        rowsToHide.append(NSIndexPath(forRow: originatingNode.visibleTraversalIndex()!, inSection: 0))
        originatingNode.isVisible = false
        
        rowsToHide.append(NSIndexPath(forRow: visibleTraversalIndex()!, inSection: 0))
        isVisible = false
        
        return rowsToHide
    }
    
    var indicesToBeHidden: NSIndexSet {
        let rowsDeleted = NSMutableIndexSet()
        
        var firstRemovalIndex = anchorNode.visibleTraversalIndex()! + 1
        var removeRange = anchorNode.visibleTraversalCount()
        
        if triggeredFromPreviousCollapsedSecton {
//            firstRemovalIndex++
//            removeRange--
        }
        
        rowsDeleted.addIndexesInRange(NSMakeRange(firstRemovalIndex, removeRange))
        
        return rowsDeleted.copy() as! NSIndexSet
    }
    
    var nodesToBeHidden: [IMGTreeNode] {
        var nodes = anchorNode.infixTraversal()
        return nodes
    }
    
    // MARK: Initializers
    
    required init(parentNode nodesParent: IMGTreeNode) {
        fatalError("init(parentNode:) has not been implemented")
    }
    
    required convenience init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(parentNode: IMGTreeNode, isVisible: Bool) {
        self.originatingNode = parentNode
        self.originalAnchorNode = parentNode.collapsedAnchorNode.copy() as! IMGTreeNode
        super.init(parentNode: parentNode)
    }
    
    // MARK: Insertion and removal
    
    func insertCollapsedSectionIntoTree() -> [NSIndexPath] {
        var indices: [NSIndexPath] = []
        isVisible = true
        anchorNode.children = []
        anchorNode.addChild(self)
        indices.append(NSIndexPath(forRow: visibleTraversalIndex()!, inSection: 0))
        addChild(originatingNode)
        originatingNode.isVisible = true
        indices.append(NSIndexPath(forRow: originatingNode.visibleTraversalIndex()!, inSection: 0))
        for child in originatingNode.children {
            child.isVisible = true
            indices.append(NSIndexPath(forRow: child.visibleTraversalIndex()!, inSection: 0))
        }
        return indices
    }
    
    func restoreCollapsedSection() -> [NSIndexPath] {
        
        anchorNode.children = originalAnchorNode.children
        for node in anchorNode.children {
            node.isVisible = true
        }
        
        let restoredIndices = anchorNode.visibleIndicesForTraversal()
        return restoredIndices
    }
    
    //MARK: NSCopying
    
   override  func copyWithZone(zone: NSZone) -> AnyObject {
        var nodeCopy = self.dynamicType(parentNode: originatingNode, isVisible: isVisible)
        nodeCopy.children = children.map({ (childNode: IMGTreeNode) -> IMGTreeNode in
            return childNode.copy() as! IMGTreeNode
        })
        return nodeCopy
    }
    
    //MARK: DebugPrintable
    
    override var description : String {
        return "Collapsed Node: \(rootNode.visibleIndexForNode(self)!) \n"
    }
}