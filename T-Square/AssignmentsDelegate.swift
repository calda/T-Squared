//
//  AssignmentsDelegate.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 9/12/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation
import UIKit

class AssignmentsDelegate : NSObject, StackableTableDelegate {
    
    let controller: ClassesViewController
    let owningClass: Class
    var assignments: [Assignment] = []
    
    init(owningClass: Class, controller: ClassesViewController) {
        self.owningClass = owningClass
        self.controller = controller
    }
    
    //MARK: - Table View Delegate
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (assignments.count == 0 ? 1 : assignments.count) + 2
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.item == 0 {
            let cell = tableView.dequeueReusableCellWithIdentifier("back")!
            cell.hideSeparator()
            return cell
        }
        if indexPath.item == 1 {
            let cell = tableView.dequeueReusableCellWithIdentifier("boldTitle")! as! TitleCell
            cell.decorate("Assignments in \(owningClass.name)")
            return cell
        }
        if indexPath.item == 2 && assignments.count == 0 {
            let cell = tableView.dequeueReusableCellWithIdentifier("subtitle")! as! TitleCell
            cell.decorate("Nothing here yet.")
            return cell
        }
        let assignment = assignments[indexPath.item - 2]
        let cell = tableView.dequeueReusableCellWithIdentifier("assignment") as! AssignmentCell
        cell.decorate(assignment)
        return cell
    }
    
    @objc func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return indexPath.item == 0 || indexPath.item == 1 ? 50.0 : 70.0
    }
    
    //MARK: - Stackable Table Delegate Methods
    
    func loadData() {
        let classAssignments = TSAuthenticatedReader.getAssignmentsForClass(owningClass)
        self.assignments = classAssignments.sort({ item1, item2 in
            if let date1 = item1.dueDate, let date2 = item2.dueDate {
                return date1.timeIntervalSinceDate(date2) > 0
            }
            return false
        })
    }
    
    func loadCachedData() {
        assignments = owningClass.assignments ?? []
        return
    }
    
    func isFirstLoad() -> Bool {
        return owningClass.assignments == nil
    }
    
    func processSelectedCell(index: NSIndexPath) {
        if index.item == 0 || (index.item == 1) || (index.item == 2 && assignments.count == 0) { return }
        
        let assignment = assignments[index.item - 2]
        if assignment.message == nil {
            controller.setActivityIndicatorVisible(true)
        }
        
        let delegate = AssignmentDelegate(assignment: assignment, controller: self.controller)
        delegate.loadDataAndPushInController(controller)
    }
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        return index.item != 0 && index.item != 1 && (assignments.count == 0 ? index.item != 2 : true)
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