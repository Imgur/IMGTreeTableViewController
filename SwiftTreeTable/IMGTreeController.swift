//
//  IMGTreeController.swift
//  SwiftTreeTable
//
//  Created by Geoff MacDonald on 3/26/15.
//  Copyright (c) 2015 Geoff MacDonald. All rights reserved.
//

import UIKit

@objc(IMGTreeControllerDelegate)
protocol IMGTreeControllerDelegate {
    func cell(node: IMGTreeNode, indexPath: NSIndexPath) -> UITableViewCell
    func collapsedCell(node: IMGTreeNode, indexPath: NSIndexPath) -> UITableViewCell
    optional func actionCell(node: IMGTreeNode, indexPath: NSIndexPath) -> UITableViewCell
    optional func selectionCell(node: IMGTreeNode, indexPath: NSIndexPath) -> UITableViewCell
}

@objc(IMGTreeController)
class IMGTreeController: NSObject, UITableViewDataSource{
    
    var delegate: IMGTreeControllerDelegate!
    var tableView: UITableView!
    var collapsedSectionDepth = 3
    var tree: IMGTree? {
        didSet {
            if tree != nil {
                tree!.rootNode.isVisible = true
                setNodeChildrenVisiblility(tree!.rootNode, visibility: true)
            }
            tableView.reloadData()
        }
    }
    var transactionInProgress: Bool {
        didSet {
            if transactionInProgress == false {
                commit()
            } else {
                insertedNodes = []
                deletedNodes = []
            }
        }
    }
    var insertedNodes: [IMGTreeNode] = []
    var deletedNodes: [IMGTreeNode] = []
    
    var selectionNode: IMGTreeSelectionNode?
    var actionNode: IMGTreeActionNode?
    
    //MARK: initializers
    
    required init(tableView: UITableView, delegate: IMGTreeControllerDelegate) {
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
                } else if !node.isChildrenVisible && node.depth > collapsedSectionDepth {
                    
                    println("node.depth = \(node.depth)")
                    let collapsedNode = IMGTreeCollapsedSectionNode(topNode: node.anchorNode, bottomNode: node)
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
    
    func insertCollapsedSectionIntoTree(collapsedNode: IMGTreeCollapsedSectionNode, animated: Bool) {
        let animationStyle = animated ? UITableViewRowAnimation.Fade : UITableViewRowAnimation.None;
        let triggeredFromPreviousCollapsedSecton = collapsedNode.triggeredFromPreviousCollapsedSecton
        
        if triggeredFromPreviousCollapsedSecton {
            let firstDeleteIndex = collapsedNode.topNode!.visibleTraversalIndex()! + 1
            tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: firstDeleteIndex, inSection: 0)], withRowAnimation: animationStyle)
        }
        
        //delete rows collapsed section will hide
        let nodesToHide = collapsedNode.nodesToBeHidden
        let nodeIndicesToHide = collapsedNode.indicesToBeHidden
        for internalNode in reverse(nodesToHide) {
            internalNode.isVisible = false
        }
        var indices: [NSIndexPath] = []
        nodeIndicesToHide.enumerateIndexesUsingBlock({ (rowIndex: NSInteger, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            indices.append(NSIndexPath(forRow: rowIndex, inSection: 0))
        })
        tableView.deleteRowsAtIndexPaths(indices, withRowAnimation: animationStyle)
        
        let indicesToShow = collapsedNode.insertCollapsedSectionIntoTree()
        tableView.insertRowsAtIndexPaths(indicesToShow, withRowAnimation: animationStyle)
        if !triggeredFromPreviousCollapsedSecton {
//            tableView.insertRowsAtIndexPaths([collapsedNode.visibleTraversalIndex()!], withRowAnimation: animationStyle)
        }
    }
    
    func restoreCollapsedSection(collapsedNode: IMGTreeCollapsedSectionNode, animated: Bool) {
        let animationStyle = animated ? UITableViewRowAnimation.Fade : UITableViewRowAnimation.None;
        let triggeredFromPreviousCollapsedSecton = collapsedNode.triggeredFromPreviousCollapsedSecton
        
        if triggeredFromPreviousCollapsedSecton {
            tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: collapsedNode.visibleTraversalIndex()!, inSection: 0)], withRowAnimation: animationStyle)
        }
        
        //delete  the containing nodes of the bottom node
        let nodeIndicesToHide = collapsedNode.indicesForContainingNodes
        tableView.deleteRowsAtIndexPaths(nodeIndicesToHide, withRowAnimation: animationStyle)
        
        if !triggeredFromPreviousCollapsedSecton {
//            tableView.insertRowsAtIndexPaths([collapsedNode.visibleTraversalIndex()!], withRowAnimation: animationStyle)
        }
        
        //restore old nodes
        let nodeIndicesToShow = collapsedNode.restoreCollapsedSection()
        tableView.insertRowsAtIndexPaths(nodeIndicesToShow, withRowAnimation: animationStyle)
    }
    
    func addSelectionNodeIfNecessary(parentNode: IMGTreeNode) -> Bool {

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
    
    func addActionNode(parentNode: IMGTreeNode) {
        
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
    
    func commit() {
        
        tableView.beginUpdates()
        
        var addedIndices: NSMutableArray = NSMutableArray()
        for node in insertedNodes {
            if let rowIndex = node.visibleTraversalIndex() {
                let indexPath = NSIndexPath(forRow: rowIndex, inSection: 0)
                addedIndices.addObject(indexPath)
            }
            addedIndices.addObjectsFromArray(node.indicesForTraversal())
        }
        tableView.insertRowsAtIndexPaths(addedIndices, withRowAnimation: .Top)
        
        var deletedIndices: NSMutableArray = NSMutableArray()
        for node in deletedNodes {
            if let rowIndex = node.previousVisibleIndex {
                let indexPath = NSIndexPath(forRow: rowIndex, inSection: 0)
                deletedIndices.addObject(indexPath)
            }
            deletedIndices.addObjectsFromArray(node.previousVisibleChildren!)
        }
        tableView.deleteRowsAtIndexPaths(deletedIndices, withRowAnimation: .Top)
        
        
        tableView.endUpdates()
    }
    

    //MARK: UITableViewDataSource
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        assert(tree != nil, "!! no tree set for indexPath: " + indexPath.description)
        return delegate.cell(tree!.rootNode.visibleNodeForIndex(indexPath.row)!, indexPath: indexPath)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tree?.rootNode.visibleTraversalCount() ?? 0
    }
}
