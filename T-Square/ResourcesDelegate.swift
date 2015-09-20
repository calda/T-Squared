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
    
    let openFolder: ResourceFolder
    let controller: ClassesViewController
    
    var allResources: [Resource] = []
    var folders: [ResourceFolder] = []
    var files: [Resource] = []

    init(controller: ClassesViewController, inFolder folder: ResourceFolder) {
        self.openFolder = folder
        self.controller = controller
    }
    
    //MARK: - Table View Methods
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return (allResources.count == 0 ? 3 : 2)
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
            if indexPath.item == 1 {
                let cell = tableView.dequeueReusableCellWithIdentifier("boldTitle")! as! TitleCell
                cell.decorate(openFolder.name)
                return cell
            }
            if indexPath.item == 2 && allResources.count == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("message-white")! as! TitleCell
                cell.decorate("Nothing here yet.")
                return cell
            }
        }
        
        //folder cells
        if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCellWithIdentifier("folder")! as! TitleCell
            let folder = folders[indexPath.item]
            cell.decorate(folder.name)
            return cell
        }
        
        //attachment cells
        if indexPath.section == 2 {
            let cell = tableView.dequeueReusableCellWithIdentifier("attachment") as! AttachmentCell
            let file = files[indexPath.item]
            cell.decorate(file.name)
            cell.hideSeparator()
            return cell
        }
        
        return tableView.dequeueReusableCellWithIdentifier("blank")!
        
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == 1 { return 40.0 }
        else { return 50.0 }
    }
    
    //MARK: - Stackable Table Delegate Methods
    
    func loadData() {
        let resources = TSAuthenticatedReader.getResourcesInFolder(openFolder)
        self.allResources = resources
        createGroupsFromAllResources()
    }
    
    func loadCachedData() {
        allResources = openFolder.resourcesInFolder ?? []
        createGroupsFromAllResources()
    }
    
    func createGroupsFromAllResources() {
        folders = []
        files = []
        
        for resource in allResources {
            if let resource = resource as? ResourceFolder {
                folders.append(resource)
            }
            else {
                files.append(resource)
            }
        }
    }
    
    func isFirstLoad() -> Bool {
        return openFolder.resourcesInFolder == nil
    }
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        return index.section != 0
    }
    
    func processSelectedCell(index: NSIndexPath) {
        if index.section == 1 {
            let folder = folders[index.item]
            let delegate = ResourcesDelegate(controller: self.controller, inFolder: folder)
            delegate.loadDataAndPushInController(controller)
        }
        if index.section == 2 {
            let file = files[index.item]
            AttachmentCell.presentResource(file, inController: controller)
        }
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