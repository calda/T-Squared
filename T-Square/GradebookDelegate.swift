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
        if indexPath.item == 1 && (scores.count == 0 || scores.count == 1) {
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
            if score.scoreString == "COMMENT_PLACEHOLDER" {
                let cell = tableView.dequeueReusableCellWithIdentifier("gradeComment")! as! TitleCell
                cell.decorate(score.name)
                cell.hideSeparator()
                return cell
            }
            
            let cell = tableView.dequeueReusableCellWithIdentifier("grade")! as! GradeCell
            cell.decorateForScore(score)
            if !(score.name == "" && score.scoreString == "") {
                cell.hideSeparator()
            }
            return cell
        }
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.item == 0 || indexPath.item == 1 && scores.count == 0 {
            return 50.0
        }
        if indexPath.item == 1 && scores.count > 0 {
            return 80.0
        }
        
        let score = scores[indexPath.item - 2]
        if score is GradeGroup { return 55.0 }
        else {
            if score.name == "" && score.scoreString == "" { return 20.0 }
            if score.scoreString == "COMMENT_PLACEHOLDER" {
                //calculate height needed to display comment
                let availableWidth: CGFloat = controller.view.frame.width - 58 - 16
                let font = UIFont.systemFontOfSize(15.0)
                return heightForText(score.name, width: availableWidth, font: font) + 20.0
            }
            return 35.0
        }
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
        scores = flattenedGrades(displayClass.grades) ?? []
    }
    
    func loadData() {
        scores = flattenedGrades(TSAuthenticatedReader.getGradesForClass(displayClass))
    }
    
    func flattenedGrades(grades: GradeGroup?) -> [Scored] {
        guard let grades = grades else { return [] }
        var flattened: [Scored] = [Grade(name: "", score: "", weight: nil, comment: nil)]
        flattened.appendContentsOf(grades.flattened)
        return flattened
    }
    
    func isFirstLoad() -> Bool {
        return displayClass.grades == nil
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: false)
        delay(0.5) {
            NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: true)
        }
    }
    
}