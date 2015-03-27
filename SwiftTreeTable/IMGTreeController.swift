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
    
    
    //MARK: initializers
    
    required init(tableView: UITableView, delegate: IMGTreeControllerDelegate) {
        self.tableView = tableView
        self.delegate = delegate
        super.init()
        tableView.dataSource = self
    }
    
    //MARK: Public
    
    func setNodeChildrenVisiblility(node: IMGTreeNode, visibility: Bool) {
        
        for child in node.children {
            child.isVisible = visibility
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        assert(tree != nil, "!! no tree set for indexPath: " + indexPath.description)
        return delegate.cell(tree!.rootNode.visibleNodeForIndex(indexPath.row)!, indexPath: indexPath)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tree?.rootNode.visibleTraversalCount() ?? 0
    }
    
    func didSelectRow(indexPath: NSIndexPath) {
        if let node = tree?.rootNode.visibleNodeForIndex(indexPath.row) {

            setNodeChildrenVisiblility(node, visibility: node.children.first?.isVisible != true ?? false)
        }
        tableView.reloadData()
    }
}
