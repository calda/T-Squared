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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (assignments.count == 0 ? 1 : assignments.count) + 2
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.item == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "back")!
            cell.hideSeparator()
            return cell
        }
        if indexPath.item == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "boldTitle")! as! TitleCell
            cell.decorate("Assignments in \(owningClass.name)")
            return cell
        }
        if indexPath.item == 2 && assignments.count == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "subtitle")! as! TitleCell
            cell.decorate("Nothing here yet.")
            return cell
        }
        let assignment = assignments[indexPath.item - 2]
        let cell = tableView.dequeueReusableCell(withIdentifier: "assignment") as! AssignmentCell
        cell.decorate(assignment)
        return cell
    }
    
    @objc func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.item == 0 || indexPath.item == 1 ? 50.0 : 70.0
    }
    
    //MARK: - Stackable Table Delegate Methods
    
    func loadData() {
        let classAssignments = TSAuthenticatedReader.getAssignmentsForClass(owningClass)
        self.assignments = classAssignments.sorted(by: { item1, item2 in
            if let date1 = item1.dueDate, let date2 = item2.dueDate {
                return date1.timeIntervalSince(date2) > 0
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
    
    func processSelectedCell(_ index: IndexPath) {
        if index.item == 0 || (index.item == 1) || (index.item == 2 && assignments.count == 0) { return }
        
        let assignment = assignments[index.item - 2]
        if assignment.message == nil {
            controller.setActivityIndicatorVisible(true)
        }
        
        let delegate = AssignmentDelegate(assignment: assignment, controller: self.controller)
        delegate.loadDataAndPushInController(controller)
    }
    
    func canHighlightCell(_ index: IndexPath) -> Bool {
        return index.item != 0 && index.item != 1 && (assignments.count == 0 ? index.item != 2 : true)
    }
    
    func animateSelection(_ cell: UITableViewCell, indexPath: IndexPath, selected: Bool) {
        let background: UIColor = UIColor(white: 1.0, alpha: selected ? 0.3 : 0.0)
        
        UIView.animate(withDuration: 0.3, animations: {
            cell.backgroundColor = background
        })
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: TSSetTouchDelegateEnabledNotification), object: false)
        delay(0.5) {
            NotificationCenter.default.post(name: Notification.Name(rawValue: TSSetTouchDelegateEnabledNotification), object: true)
        }
    }
    
}
