//
//  AllClassesDelegate.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 9/12/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation
import UIKit

class AllClassesDelegate : NSObject, StackableTableDelegate {
    
    let controller: ClassesViewController
    var allClasses: [Class] = []
    
    init(controller: ClassesViewController) {
        self.controller = controller
    }
    
    //MARK: - Table View Delegate
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (allClasses.count == 0 ? 1 : allClasses.count) + 3
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.item == 0 {
            let cell = tableView.dequeueReusableCellWithIdentifier("back")!
            cell.hideSeparator()
            return cell
        }
        if indexPath.item == 1 {
            let cell = tableView.dequeueReusableCellWithIdentifier("classTitle")! as! ClassNameCell
            cell.nameLabel.text = "All Classes"
            cell.subjectLabel.text = "Active and Hidden"
            cell.hideSeparator()
            return cell
        }
        if indexPath.item == 2 {
            return tableView.dequeueReusableCellWithIdentifier("blank")!
        }
        if indexPath.item == 3 && allClasses.count == 0 {
            let cell = tableView.dequeueReusableCellWithIdentifier("subtitle")! as! TitleCell
            cell.decorate("You aren't in any classes yet.")
            return cell
        }
        let displayClass = allClasses[indexPath.item - 3]
        let cell = tableView.dequeueReusableCellWithIdentifier("classWithIcon") as! ClassNameCellWithIcon
        cell.decorate(displayClass)
        return cell
    }
    
    @objc func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.item == 0 { return 50.0 }
        if indexPath.item == 2 { return 20.0 }
        return 70.0
    }
    
    //MARK: - Stackable Table Delegate Methods
    
    func loadData() {
        self.allClasses = TSAuthenticatedReader.getAllClasses()
    }
    
    func loadCachedData() {
        self.allClasses = TSAuthenticatedReader.allClasses ?? []
    }
    
    func isFirstLoad() -> Bool {
        return TSAuthenticatedReader.allClasses == nil
    }
    
    func processSelectedCell(index: NSIndexPath) {
        if index.item == 0 || (index.item == 1) || (index.item == 2) || (index.item == 3 && allClasses.count == 0) { return }
        
        let displayClass = allClasses[index.item - 3]
        let delegate = ClassDelegate(controller: controller, displayClass: displayClass)
        delegate.loadDataAndPushInController(controller)
    }
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        return index.item != 0 && index.item != 1 && index.item != 2 && (allClasses.count == 0 ? index.item != 3 : true)
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