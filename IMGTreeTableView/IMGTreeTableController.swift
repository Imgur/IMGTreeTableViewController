//
//  IMGTreeTableController.swift
//  SwiftTreeTable
//
//  Created by Geoff MacDonald on 3/26/15.
//  Copyright (c) 2015 Geoff MacDonald. All rights reserved.
//

import UIKit

/**
    Defines methods a controller should implement to feed UITableViewCell's to the IMGTreeTableController
*/
@objc public protocol IMGTreeTableControllerDelegate {
    func cell(node: IMGTreeNode, indexPath: NSIndexPath) -> UITableViewCell
}

/**
    This class is to be used with its tableview convenience methods to modify the contained IMGTree and alter the UITableView
*/
public class IMGTreeTableController: NSObject, UITableViewDataSource{

    /**
        Delegate conformance is required for constructing table view cells to use representing the nodes in the tree
    */
    private weak var delegate: IMGTreeTableControllerDelegate!
    /**
        Tableview this controller controls upon convenience methods
    */
    private weak var tableView: UITableView!
    /**
        The depth at which the controller will collapse intermediate (up to root) subtrees exposing only the selected cell's subtree
    */
    var collapsedSectionDepth = 3
    /**
        The tree representing the node tree displayed in the tableview. Can be nil, in which case the tableview is cleared at anytime.
    */
    var tree: IMGTree? {
        didSet {
            if tree != nil {
                tree!.rootNode.isVisible = true
                setNodeChildrenVisiblility(tree!.rootNode, visibility: true)
            }
            tableView.reloadData()
        }
    }
    
    /**
        Is the tableview currently being manipulated?
    */
    private var transactionInProgress: Bool {
        didSet {
            if transactionInProgress == false {
                commit()
            } else {
                insertedNodes = []
                deletedNodes = []
            }
        }
    }
    /**
        The nodes that are being inserted by some action
    */
    private var insertedNodes: [IMGTreeNode] = []
    /**
        The nodes that are being deleted by some action
    */
    private var deletedNodes: [IMGTreeNode] = []
    
    /**
        The currently selected node. There can only be one by design.
    */
    private var selectionNode: IMGTreeSelectionNode?
    /**
        The currently actionable node. There can only be one by design.
    */
    private var actionNode: IMGTreeActionNode?
    
    //MARK: initializers
    
    required public init(tableView: UITableView, delegate: IMGTreeTableControllerDelegate) {
        self.tableView = tableView
        self.delegate = delegate
        transactionInProgress = false
        super.init()
        tableView.dataSource = self
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "visibilityChanged:", name: "isVisibleChanged", object: nil)
    }
    
    //MARK: Public
    
    func setNodeChildrenVisiblility(parentNode: IMGTreeNode, visibility: Bool) {
        
        if !visibility {
            for child in reverse(parentNode.children) {
                if !child.isKindOfClass(IMGTreeSelectionNode) {
                    child.isVisible = visibility
                }
            }
        } else {
            for child in parentNode.children {
                child.isVisible = true
            }
        }
    }
    
    func didSelectRow(indexPath: NSIndexPath) {
        if let node = tree?.rootNode.visibleNodeForIndex(indexPath.row) {
            if !node.isKindOfClass(IMGTreeSelectionNode) && !node.isKindOfClass(IMGTreeActionNode) {
                
                if let collapsedSection = node as? IMGTreeCollapsedSectionNode {
                    restoreCollapsedSection(collapsedSection, animated: true)
                } else if !node.isChildrenVisible && node.collapsedDepth > collapsedSectionDepth {
                    
                    let collapsedNode = IMGTreeCollapsedSectionNode(parentNode: node, isVisible: false)
                    insertCollapsedSectionIntoTree(collapsedNode, animated: true)
                    
                } else {
                    
                    transactionInProgress = true
                    if addSelectionNodeIfNecessary(node) {
                        setNodeChildrenVisiblility(node, visibility: !node.isChildrenVisible)
                    }
                    transactionInProgress = false
                }
            }
        }
    }
    
    func didTriggerActionFromIndex(indexPath: NSIndexPath) {
        if let node = tree?.rootNode.visibleNodeForIndex(indexPath.row) {
            if !node.isKindOfClass(IMGTreeActionNode) {
                transactionInProgress = true
                addActionNode(node)
                transactionInProgress = false
            }
        }
    }
    
    //MARK: Private
    
    private func insertCollapsedSectionIntoTree(collapsedNode: IMGTreeCollapsedSectionNode, animated: Bool) {
        let animationStyle = animated ? UITableViewRowAnimation.Fade : UITableViewRowAnimation.None;
        let triggeredFromPreviousCollapsedSecton = collapsedNode.triggeredFromPreviousCollapsedSecton
        
        if triggeredFromPreviousCollapsedSecton {
            let firstDeleteIndex = collapsedNode.anchorNode.visibleTraversalIndex()! + 1
            tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: firstDeleteIndex, inSection: 0)], withRowAnimation: animationStyle)
        }
        
        //delete rows collapsed section will hide
        let nodesToHide = collapsedNode.nodesToBeHidden
        let nodeIndicesToHide = collapsedNode.indicesToBeHidden
        for internalNode in reverse(nodesToHide) {
            internalNode.isVisible = false
        }
        assert(nodesToHide.count == nodeIndicesToHide.count, "deleted nodes and indices count not equivalent")
        var indices: [NSIndexPath] = []
        nodeIndicesToHide.enumerateIndexesUsingBlock({ (rowIndex: NSInteger, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            indices.append(NSIndexPath(forRow: rowIndex, inSection: 0))
        })
        
        assert(tree!.rootNode.visibleTraversalCount() == tableView.numberOfRowsInSection(0) - nodesToHide.count, "during collapsed section insertion: deleted nodes and indices count not equivalent")
        tableView.deleteRowsAtIndexPaths(indices, withRowAnimation: animationStyle)
        
        var indicesToShow = collapsedNode.insertCollapsedSectionIntoTree()
        
        selectionNode = IMGTreeSelectionNode(parentNode: collapsedNode.originatingNode)
        collapsedNode.originatingNode.addChild(self.selectionNode!)
        self.selectionNode?.isVisible = true
        
        let lastIndice = indicesToShow.last!
        indicesToShow.append(NSIndexPath(forRow: lastIndice.row + 1, inSection: 0))
        
        assert(tree!.rootNode.visibleTraversalCount() == tableView.numberOfRowsInSection(0) + indicesToShow.count, "during collapsed section insertion: inserted nodes and indices count not equivalent")
        tableView.insertRowsAtIndexPaths(indicesToShow, withRowAnimation: animationStyle)
    }
    
    private func restoreCollapsedSection(collapsedNode: IMGTreeCollapsedSectionNode, animated: Bool) {
        let animationStyle = animated ? UITableViewRowAnimation.Fade : UITableViewRowAnimation.None;
        let triggeredFromPreviousCollapsedSecton = collapsedNode.triggeredFromPreviousCollapsedSecton
        
        if triggeredFromPreviousCollapsedSecton {
            tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: collapsedNode.visibleTraversalIndex()!, inSection: 0)], withRowAnimation: animationStyle)
        }
        
        //delete  the containing nodes of the bottom node
        let nodeIndicesToHide = collapsedNode.indicesForContainingNodes
        assert(tree!.rootNode.visibleTraversalCount() == tableView.numberOfRowsInSection(0) - nodeIndicesToHide.count, "during collapsed section restore: deleted nodes and indices count not equivalent")
        tableView.deleteRowsAtIndexPaths(nodeIndicesToHide, withRowAnimation: animationStyle)
        
        //restore old nodes
        var needsSelection = false
        if collapsedNode.anchorNode.isSelected {
            needsSelection = true
        }
        var nodeIndicesToShow = collapsedNode.restoreCollapsedSection()
        if needsSelection{
            nodeIndicesToShow = nodeIndicesToShow.map({ (var index: NSIndexPath) -> NSIndexPath in
                index = NSIndexPath(forRow: index.row + 1, inSection: index.section)
                return index
            })
            collapsedNode.anchorNode.children.insert(selectionNode!, atIndex: 0)
        }
        //we need to also restore the selectionNode and actionNode properties if a selection node existed in the restored subtreee
        if let priorSelection = collapsedNode.anchorNode.selectionNodeInTraversal() {
            selectionNode = priorSelection
        }
        if let priorAction = collapsedNode.anchorNode.actionNodeInTraversal() {
            actionNode = priorAction
        }
        
        assert(tree!.rootNode.visibleTraversalCount() == tableView.numberOfRowsInSection(0) + nodeIndicesToShow.count, "during collapsed section restore: inserted nodes and indices count not equivalent")
        tableView.insertRowsAtIndexPaths(nodeIndicesToShow, withRowAnimation: animationStyle)
    }
    
    private func addSelectionNodeIfNecessary(parentNode: IMGTreeNode) -> Bool {

        if !parentNode.isSelected{
            let needsChildToggling = parentNode.isSelectionNodeInVisibleTraversal() || parentNode.isChildrenVisible
            
            if self.selectionNode != nil {
                //hide previous selection node
                self.selectionNode?.removeFromParent()
            }
            
            self.selectionNode = IMGTreeSelectionNode(parentNode: parentNode)
            parentNode.addChild(self.selectionNode!)
            self.selectionNode?.isVisible = true
            
            return !needsChildToggling
        } else {
            return true
        }
    }
    
    private func addActionNode(parentNode: IMGTreeNode) {
        
        if self.actionNode != nil {
            
            //hide previous selection node
            self.actionNode?.removeFromParent()
        }
        
        self.actionNode = IMGTreeActionNode(parentNode: parentNode)
        parentNode.addChild(self.actionNode!)
        self.actionNode?.isVisible = true
    }
    
    func visibilityChanged(notification: NSNotification!) {
        let node = notification.object! as! IMGTreeNode
        if node.isVisible {
            insertedNodes.append(node)
        } else {
            deletedNodes.append(node)
        }
    }
    
    private func commit() {
        
        tableView.beginUpdates()
        
        var addedIndices: [AnyObject] = []
        for node in insertedNodes {
            if let rowIndex = node.visibleTraversalIndex() {
                let indexPath = NSIndexPath(forRow: rowIndex, inSection: 0)
                addedIndices.append(indexPath)
            }
            addedIndices.extend(node.visibleIndicesForTraversal() as [AnyObject])
        }
        tableView.insertRowsAtIndexPaths(addedIndices, withRowAnimation: .Top)
        
        var deletedIndices: [AnyObject] = []
        for node in deletedNodes {
            if let rowIndex = node.previousVisibleIndex {
                let indexPath = NSIndexPath(forRow: rowIndex, inSection: 0)
                deletedIndices.append(indexPath)
            }
            deletedIndices.extend(node.previousVisibleChildren! as [AnyObject])
        }
        tableView.deleteRowsAtIndexPaths(deletedIndices, withRowAnimation: .Top)
        
        
        tableView.endUpdates()
    }
    

    //MARK: UITableViewDataSource
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        assert(tree != nil, "!! no tree set for indexPath: " + indexPath.description)
        return delegate.cell(tree!.rootNode.visibleNodeForIndex(indexPath.row)!, indexPath: indexPath)
    }
    
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tree?.rootNode.visibleTraversalCount() ?? 0
    }
}
