//
//  AssignmentsDelegate.swift
//  T-Square
//
//  Created by Cal on 9/12/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import UIKit

class AssignmentsDelegate : NSObject, StackableTableDelegate {
    
    let controller: ClassesViewController
    let assignments: [Assignment]
    
    init(assignments: [Assignment], controller: ClassesViewController) {
        self.controller = controller
        self.assignments = assignments.sort({ item1, item2 in
            if let date1 = item1.dueDate, let date2 = item2.dueDate {
                return date1.timeIntervalSinceDate(date2) > 0
            }
            return false
        })
    }
    
    //MARK: - Table View Delegate
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return assignments.count + 1
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.item == 0 {
            return tableView.dequeueReusableCellWithIdentifier("back")!
        }
        let assignment = assignments[indexPath.item - 1]
        let cell = tableView.dequeueReusableCellWithIdentifier("assignment") as! AssignmentCell
        cell.decorate(assignment)
        return cell
    }
    
    @objc func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return indexPath.item == 0 ? 50.0 : 70.0
    }
    
    //MARK: - Stackable Table Delegate Methods
    
    func processSelectedCell(index: NSIndexPath) {
        if index.item == 0 || (index.item == 1 && assignments.count == 0) { return }
        
        let assignment = assignments[index.item - 1]
        if assignment.message == nil {
            controller.setActivityIndicatorVisible(true)
        }
        
        dispatch_async(TSNetworkQueue) {
            assignment.loadMessage()
            let delegate = AssignmentDelegate(assignment: assignment, controller: self.controller)
            sync {
                self.controller.pushDelegate(delegate)
                self.controller.setActivityIndicatorVisible(false)
            }
        }
    }
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        return index.item != 0
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