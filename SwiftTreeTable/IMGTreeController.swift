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
    
    
    func setNodeChildrenVisiblility(node: IMGTreeNode, visibility: Bool) {
        
        if !visibility {
            for child in reverse(node.children) {
                if !child.isKindOfClass(IMGTreeSelectionNode) {
                    child.isVisible = visibility
                }
            }
        } else {
            for child in node.children {
                child.isVisible = true
            }
        }
    }
    
    func didSelectRow(indexPath: NSIndexPath) {
        if let node = tree?.rootNode.visibleNodeForIndex(indexPath.row) {
            if !node.isKindOfClass(IMGTreeSelectionNode) && !node.isKindOfClass(IMGTreeActionNode) {
                transactionInProgress = true
                if addSelectionNodeIfNecessary(node) {
                    setNodeChildrenVisiblility(node, visibility: !node.isChildrenVisible)
                } else {
                    println("prevented child toggling at node: \(node.visibleTraversalIndex()?.description)")
                }
                transactionInProgress = false
            }
        }
    }
    
    //MARK: Private
    
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
    
    func visibilityChanged(notification: NSNotification!) {
        let node = notification.object! as IMGTreeNode
        if node.isVisible {
            insertedNodes.append(node)
        } else {
            deletedNodes.append(node)
        }
    }
    
    func commit() {
        
        tableView.beginUpdates()
        
        var addedIndices: NSMutableSet = NSMutableSet()
        for node in insertedNodes {
            if let rowIndex = node.visibleTraversalIndex() {
                let indexPath = NSIndexPath(forRow: rowIndex, inSection: 0)
                addedIndices.addObject(indexPath)
            }
            addedIndices.addObjectsFromArray(node.indicesForTraversal())
        }
        tableView.insertRowsAtIndexPaths(addedIndices.allObjects, withRowAnimation: .Top)
        
        var deletedIndices: NSMutableSet = NSMutableSet()
        for node in deletedNodes {
            if let rowIndex = node.previousVisibleIndex {
                let indexPath = NSIndexPath(forRow: rowIndex, inSection: 0)
                deletedIndices.addObject(indexPath)
            }
            deletedIndices.addObjectsFromArray(node.previousVisibleChildren!)
        }
        tableView.deleteRowsAtIndexPaths(deletedIndices.allObjects, withRowAnimation: .Top)
        
        
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
