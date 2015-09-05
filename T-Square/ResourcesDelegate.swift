//
//  ResourcesDelegate.swift
//  T-Square
//
//  Created by Cal on 9/4/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import UIKit

class ResourcesDelegate : NSObject, StackableTableDelegate {
    
    let owningClass: Class
    let controller: ClassesViewController
    
    let allResources: [Resource]
    var folders: [Resource] = []
    var files: [Resource] = []

    init(controller: ClassesViewController, resources: [Resource], inClass owningClass: Class) {
        self.owningClass = owningClass
        self.controller = controller
        self.allResources = resources
        
        for resource in resources {
            if resource.isFolder {
                folders.append(resource)
            }
            else {
                files.append(resource)
            }
        }
    }
    
    //MARK: - Table View Methods
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return (allResources.count == 0 ? 2 : 1)
        }
        if section == 1 { return folders.count }
        else { return files.count } //section == 2
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        //heading cells
        if indexPath.section == 0 {
            if indexPath.item == 0 {
                return tableView.dequeueReusableCellWithIdentifier("back")!
            }
            if indexPath.item == 0 && allResources.count == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("message-white")! as! TitleCell
                cell.decorate("Nothing here yet.")
                return cell
            }
        }
        
        //folder cells
        if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCellWithIdentifier("standardTitle")! as! TitleCell
            let folder = folders[indexPath.item]
            cell.decorate(folder.name)
            return cell
        }
        
        //attachment cells
        if indexPath.section == 2 {
            let cell = tableView.dequeueReusableCellWithIdentifier("attachment") as! AttachmentCell
            let file = files[indexPath.item]
            cell.decorate(file.name)
            return cell
        }
        
        return tableView.dequeueReusableCellWithIdentifier("blank")!
        
    }
    
    //MARK: - Stackable Table Delegate Methods
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        return index.section != 0
    }
    
    func processSelectedCell(index: NSIndexPath) {
        return
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: false)
        delay(0.5) {
            NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: true)
        }
    }
    
    func animateSelection(cell: UITableViewCell, indexPath: NSIndexPath, selected: Bool) {
        let background = UIColor(white: 1.0, alpha: selected ? 0.3 : 0.0)
        
        UIView.animateWithDuration(0.3, animations: {
            cell.backgroundColor = background
        })
    }
    
}