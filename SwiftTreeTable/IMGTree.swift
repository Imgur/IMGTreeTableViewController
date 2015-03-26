import UIKit

class IMGTree: NSObject, NSCoding {
    
    let rootNode:IMGTreeNode
    
    override init() {
        rootNode = IMGTreeNode()
    }
 
    required convenience init(coder aDecoder: NSCoder) {
        self.init()
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        
    }
}

class IMGTreeNode: NSObject, NSCoding {
    
    weak var parentNode: IMGTreeNode?
    var children: [IMGTreeNode]? {
        didSet {
            children = children?.map({ (var node: IMGTreeNode) -> IMGTreeNode in
                node.parentNode = self
                return node
            })
        }
    }
    var rootNode: IMGTreeNode {
        get {
            var currentNode: IMGTreeNode? = self
            
            while currentNode != nil {
                currentNode = currentNode!.parentNode
            }
            
            return currentNode!
        }
    }
    var isVisible: Bool
    
    //MARK: Initializers
    
    override init() {
        isVisible = false
    }
    
    //MARK: NSCoding
    
    required convenience init(coder aDecoder: NSCoder) {
        self.init()
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        
    }
    
    //MARK: Public
    
    func addChild(child: IMGTreeNode) {
        if var childNodes = children {
            childNodes += [child]
            
            // Ensure didSet gets called
            children = childNodes
        }
    }
    
    func removeChild(child: IMGTreeNode) {
        if var childNodes = children {
            if let targetIndex = find(childNodes, child) {
                children!.removeAtIndex(targetIndex)
            }
        }
    }
    
    func hasSelectionNode() -> Bool {
        return findChildNode(IMGTreeSelectionNode) != nil
    }
    
    func hasActionNode() -> Bool {
        return findChildNode(IMGTreeActionNode) != nil
    }
    
    func indexForNode(node: IMGTreeNode) -> Int? {
        if let traversal = infixTraversal() {
            return find(traversal, node)
        }
        
        return nil
    }
    
    func traversalIndex() -> Int? {
        return rootNode.indexForNode(self)
    }
    
    //MARK: Private
    
    private func infixTraversal() -> [IMGTreeNode]? {
        var traversal: [IMGTreeNode] = []
        if let childNodes = children {
            for node in childNodes {
                traversal.append(node)
                
                if let childTraversal = node.infixTraversal() {
                    traversal.extend(childTraversal)
                }
            }
            
            return traversal
        }
        
        return nil
    }
    
    private func findChildNode(ofClass: AnyClass) -> IMGTreeNode? {
        if let childNodes = children {
            let filtered = childNodes.filter({ (node) -> Bool in
                return node.isKindOfClass(ofClass)
            })
            
            return filtered.first
        }
        
        return nil
    }
}

class IMGTreeSelectionNode {
    
}

class IMGTreeActionNode {
    
}