//
//  File.swift
//  T-Square
//
//  Created by Cal on 9/27/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import UIKit

class GradebookDelegate : NSObject, StackableTableDelegate {
    
    let displayClass: Class
    let controller: ClassesViewController
    var scores: [Scored] = []
    
    init(forClass: Class, controller: ClassesViewController) {
        self.displayClass = forClass
        self.controller = controller
    }
    
    //MARK: - Table View Controller methods
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1 + (scores.count == 0 ? 1 : scores.count + 1)
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.item == 0 {
            return tableView.dequeueReusableCellWithIdentifier("back")!
        }
        if indexPath.item == 1 && scores.count == 0 {
            let cell = tableView.dequeueReusableCellWithIdentifier("standardTitle")! as! TitleCell
            cell.decorate("Nothing here yet.")
            return cell
        }
        if indexPath.item == 1 && scores.count != 0 {
            let cell = tableView.dequeueReusableCellWithIdentifier("classTitle") as! ClassNameCell
            cell.nameLabel.text = displayClass.grades?.scoreString ?? "--%"
            cell.subjectLabel.text = "Current grade in \(displayClass.name)"
            return cell
        }
        
        let score = scores[indexPath.item - 2]
        if let group = score as? GradeGroup {
            let cell = tableView.dequeueReusableCellWithIdentifier("gradeGroup")! as! GradeGroupCell
            cell.decorateForGradeGroup(group)
            return cell
        }
        else {
            let cell = tableView.dequeueReusableCellWithIdentifier("grade")! as! GradeCell
            cell.decorateForScore(score)
            return cell
        }
    }
    
    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.item == 0 || indexPath.item == 1 && scores.count == 0 {
            return 50.0
        }
        if indexPath.item == 1 && scores.count > 0 {
            return 80.0
        }
        
        let score = scores[indexPath.item - 2]
        if score is GradeGroup { return 49.0 }
        else { return 40.0 }
    }
    
    //MARK: - Stackable Table Delegate methods
    
    func processSelectedCell(index: NSIndexPath) {
        return
    }
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        return false
    }
    
    func animateSelection(cell: UITableViewCell, indexPath: NSIndexPath, selected: Bool) {
        return
    }
    
    func loadCachedData() {
        scores = displayClass.grades?.flattened ?? []
    }
    
    func loadData() {
        scores = TSAuthenticatedReader.getGradesForClass(displayClass).flattened
    }
    
    func isFirstLoad() -> Bool {
        return displayClass.grades == nil
    }
    
}