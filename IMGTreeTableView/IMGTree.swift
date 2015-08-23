
import UIKit

/**
    This protocol allows a given class to fully configure an IMGTree instance with any given object graph
*/
@objc public protocol IMGTreeConstructorDelegate  {
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
public class IMGTree: NSObject, NSCoding, NSCopying {
    
    /**
        Defines the root node which is never displayed on screen but contains the top level nodes
    */
    public let rootNode: IMGTreeNode
    
    public override init() {
        rootNode = IMGTreeNode()
    }
    
    init(rootNode: IMGTreeNode) {
        self.rootNode = rootNode
    }
    
    //MARK: tree construction class methods
    
    /**
        Creates a new instance of IMGTree given the root level model objects and constructor object conforming to IMGTreeConstructorDelegate
    */
    public class func tree(fromRootArray rootArray: [AnyObject], withConstructerDelegate constructorDelegate: IMGTreeConstructorDelegate) -> IMGTree
    {
        let tree = IMGTree()
        let nodeClass = constructorDelegate.classForNode()
        var childNodes: [IMGTreeNode] = []
        
        // go through each top level object creating the resulting node subtree for each one recursively with the process(:::) method
        for rootObject in rootArray {
            let rootNode = nodeClass.init(parentNode: tree.rootNode)
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
            let childNode = nodeClass.init(parentNode: parentNode)
            constructorDelegate.configureNode(childNode, modelObject: childObject)
            if let childObjects = constructorDelegate.childrenForNodeObject(childObject) {
                childNode.children = IMGTree.process(tree.rootNode, childObjects: childObjects, tree: tree, constructorDelegate: constructorDelegate) as! [IMGTreeNode]
            }
            childNodes.append(childNode)
        }
        
        return childNodes
    }
    
    //MARK: Public
    
    func numNodes () -> Int {
        return rootNode.traversalCount()
    }
    
    //MARK: NSCoding
    
    required convenience public init?(coder aDecoder: NSCoder) {
        self.init()
        //TODO: implementation
    }
    
    public func encodeWithCoder(aCoder: NSCoder) {
        //TODO: implementation
    }
    
    //MARK: NSCopying
    
    public func copyWithZone(zone: NSZone) -> AnyObject {
        let treeCopy = IMGTree()
        var rootNodes: [IMGTreeNode] = []
        for node in rootNode.children {
            rootNodes.append(node.copy() as! IMGTreeNode)
        }
        treeCopy.rootNode.children = rootNodes
        return treeCopy
    }
    
    //MARK: DebugPrintable
    
    public override var description : String {
        //print readable string
        return "Tree with \(numNodes()) nodes"
    }
}


/**
    Represents an individual node which in turn represents a model object in a graph. Conforms to NSCopying in order to copy into subtree properties
*/
public class IMGTreeNode: NSObject, NSCoding, NSCopying {
    
    /**
        The controller that owns
    */
    weak var controller: IMGTreeTableController? {
        didSet {
            // recursive 
            for node in children {
                node.controller = controller
            }
        }
    }
    /**
        The super node that owns this instance as part of it's children
    */
    weak var parentNode: IMGTreeNode? {
        didSet {
            controller = parentNode?.controller
        }
    }
    /**
        This node's children nodes
    */
    public var children: [IMGTreeNode] = [] {
        didSet {
            children = children.map({ (node: IMGTreeNode) -> IMGTreeNode in
                node.parentNode = self
                node.controller = self.controller
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
    public var depth: Int {
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
            if isChildrenVisibleOverride != nil {
                return isChildrenVisibleOverride!
            }
            if children.count > 0 {
                return children.first!.isVisible
            }
            return false
        }
    }
    var isChildrenVisibleOverride: Bool?
    /**
    Does this node contain model object children (selectable cells)
    */
    var containsSelectableChildren: Bool {
        get {
            if children.count > 0 {
                for node in children {
                    if !(node.isKindOfClass(IMGTreeSelectionNode.self) || node.isKindOfClass(IMGTreeActionNode.self)){
                        return true
                    }
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
        Finds the number of visible child nodes
    */
    var visibleTraversalCount: Int {
        return infixTraversal().count ?? 0
    }
    /**
        Is the node visible within the tree?
    */
    var isVisible: Bool = false {
        willSet {
            //keep track of prior subtree visibility
            if isVisible {
                previousVisibleIndex = visibleTraversalIndex()
                previousVisibleChildren = visibleIndicesForTraversal()
            } else {
                previousVisibleChildren = []
            }
        }
        didSet {
            if isVisible != oldValue {
                //inform of change in visibility
                controller?.visibilityChangedForNode(self)
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
        //needs to be declared to allow root node to be initialized even though this is an NSObject
    }
    
    /**
        Initialize under a parent node invisibily
    */
    public required init (parentNode nodesParent: IMGTreeNode) {
        super.init()
        parentNode = nodesParent
    }
    
    
    //MARK: NSCoding
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("")
    }
    
    public func encodeWithCoder(aCoder: NSCoder) {
        
    }
    
    //MARK: Public
    
    /**
        Add the child node to the node as a child. If its a special node, it is inserted at the top.
    */
    func addChild(child: IMGTreeNode, toIndex:Int? = nil) {
        if toIndex != nil  {
            children.insert(child, atIndex: toIndex!)
        } else {
            children += [child]
        }
        child.parentNode = self
    }
    
    /**
        Remove a child.
    */
    func removeChild(child: IMGTreeNode) {
        if let targetIndex = children.indexOf(child) {
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
        var traversal = infixTraversal(false)
        return traversal.indexOf(node)
    }
    
    /**
        Finds the location, if any, of the node with this instances visible children
    */
    func visibleIndexForNode(node: IMGTreeNode) -> Int? {
        let traversal = infixTraversal()
        return traversal.indexOf(node)
    }
    
    /**
    Finds the number of visible child nodes
    */
    func traversalCount() -> Int {
        return infixTraversal(false).count ?? 0
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
    func isSelectionNodeInTraversal(visible: Bool? = true) -> Bool {
        let traversal = infixTraversal(visible!)
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
    func infixTraversal(visible: Bool = true) -> [IMGTreeNode] {
        
        var traversal = { (childNodes: [IMGTreeNode]) -> [IMGTreeNode] in
            var traversal: [IMGTreeNode] = []
            for node in childNodes {
                traversal.append(node)
                traversal.extend(node.infixTraversal(visible))
            }
            if visible && self.rootNode == self && !self.preventCacheUse {
                self.visibleInfixCache = traversal
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
    Prevents the traversal cache from being used.
    */
    var preventCacheUse = false {
        didSet {
            if preventCacheUse == false {
                //clear the cache
                visibleInfixCache = nil
            }
        }
    }
    /**
    Caches the traversal. Currently only used on the root node
    */
    var visibleInfixCache: [IMGTreeNode]?
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
    
    public override var description : String {
        if parentNode != nil {
            
            return "Node: \(visibleTraversalIndex()) \n"
        }
        return "Root Node"
    }
    
    //MARK: NSCopying
    
    public func copyWithZone(zone: NSZone) -> AnyObject {
        let nodeCopy = self.dynamicType.init(parentNode: parentNode!)
        nodeCopy.controller = controller
        nodeCopy.isVisible = isVisible
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
public class IMGTreeSelectionNode : IMGTreeNode {
    
}

/**
    Class for nodes that represent actionables things on the parent
*/
public class IMGTreeActionNode : IMGTreeNode {
    
}

/**
    Class for nodes that represent collapsed sections
*/
public class IMGTreeCollapsedSectionNode : IMGTreeNode {
    
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
        if parentNode != nil {
            return originalAnchorNode.children.first!.isKindOfClass(IMGTreeCollapsedSectionNode)
        } else {
            return anchorNode.children.first!.isKindOfClass(IMGTreeCollapsedSectionNode)
        }
    }
    
    var indicesForContainingNodes: [NSIndexPath] {
        var rowsToHide: [NSIndexPath] = []
        
        rowsToHide.extend(originatingNode.visibleIndicesForTraversal())
        originatingNode.children.map({ (child: IMGTreeNode) -> IMGTreeNode in
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
        
        let firstRemovalIndex = anchorNode.visibleTraversalIndex()! + 1
        let removeRange = anchorNode.visibleTraversalCount
        
        rowsDeleted.addIndexesInRange(NSMakeRange(firstRemovalIndex, removeRange))
        
        return rowsDeleted.copy() as! NSIndexSet
    }
    
    var nodesToBeHidden: [IMGTreeNode] {
        let nodes = anchorNode.infixTraversal()
        return nodes
    }
    
    // MARK: Initializers
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public required init(parentNode: IMGTreeNode) {
        self.originatingNode = parentNode
        self.originalAnchorNode = parentNode.collapsedAnchorNode.copy() as! IMGTreeNode
        super.init(parentNode: parentNode)
    }
    
    // MARK: Insertion and removal
    
    func insertCollapsedSectionIntoTree() -> [NSIndexPath] {
        var indices: [NSIndexPath] = []
        anchorNode.children = []
        anchorNode.addChild(self, toIndex: 0)
        isVisible = true
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
    
   public override  func copyWithZone(zone: NSZone) -> AnyObject {
        let nodeCopy = self.dynamicType.init(parentNode: originatingNode)
        nodeCopy.isVisible = isVisible
        nodeCopy.children = children.map({ (childNode: IMGTreeNode) -> IMGTreeNode in
            return childNode.copy() as! IMGTreeNode
        })
        return nodeCopy
    }
    
    //MARK: DebugPrintable
    
    public override var description : String {
        return "Collapsed Node: \(rootNode.visibleIndexForNode(self)!) \n"
    }
}