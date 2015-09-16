//
//  allClassesDelegate.swift
//  T-Square
//
//  Created by Cal on 9/12/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import UIKit

class AllClassesDelegate : NSObject, StackableTableDelegate {
    
    let controller: ClassesViewController
    let allClasses: [Class]
    
    init(allClasses: [Class], controller: ClassesViewController) {
        self.controller = controller
        self.allClasses = allClasses
    }
    
    //MARK: - Table View Delegate
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (allClasses.count == 0 ? 1 : allClasses.count) + 2
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.item == 0 {
            let cell = tableView.dequeueReusableCellWithIdentifier("back")!
            cell.hideSeparator()
            return cell
        }
        if indexPath.item == 1 {
            let cell = tableView.dequeueReusableCellWithIdentifier("boldTitle")! as! TitleCell
            cell.decorate("All Classes (Active and Hidden)")
            return cell
        }
        if indexPath.item == 2 && allClasses.count == 0 {
            let cell = tableView.dequeueReusableCellWithIdentifier("subtitle")! as! TitleCell
            cell.decorate("You aren't in any classes yet. Welcome to Tech.")
            return cell
        }
        let displayClass = allClasses[indexPath.item - 2]
        let cell = tableView.dequeueReusableCellWithIdentifier("class") as! ClassNameCell
        cell.decorate(displayClass)
        return cell
    }
    
    @objc func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return indexPath.item == 0 || indexPath.item == 1 ? 50.0 : 70.0
    }
    
    //MARK: - Stackable Table Delegate Methods
    
    func processSelectedCell(index: NSIndexPath) {
        if index.item == 0 || (index.item == 1) || (index.item == 2 && allClasses.count == 0) { return }
        
        let displayClass = allClasses[index.item - 2]
        let delegate = ClassDelegate(controller: controller, displayClass: displayClass)
        controller.pushDelegate(delegate)
    }
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        return index.item != 0 && index.item != 1 && (allClasses.count == 0 ? index.item != 2 : true)
    }
    
    func animateSelection(cell: UITableViewCell, indexPath: NSIndexPath, selected: Bool) {
        let background: UIColor = UIColor(white: 1.0, alpha: selected ? 0.3 : 0.0)
        
        UIView.animateWithDuration(0.3, animations: {
            cell.backgroundColor = background
        })
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: false)
        delay(0.5) {
            NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: true)
        }
    }
    
}