//
//  File.swift
//  T-Square
//
//  Created by Cal on 9/27/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import UIKit

let TSGradebookCalculationSettingKey = "edu.gatech.cal.gradebookCalculationSetting"
let TSCustomGradesKey = "edu.gatech.cal.customGrades"

class GradebookDelegate : NSObject, StackableTableDelegate {
    
    let displayClass: Class
    let controller: ClassesViewController
    var scores: [Scored] = []
    var showCalculationSwitch: Bool = false
    
    init(forClass: Class, controller: ClassesViewController) {
        self.displayClass = forClass
        self.controller = controller
    }
    
    //MARK: - Table View Controller methods
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 { return 1 }
        return 2 + (scores.count == 0 ? 1 : scores.count + 1)
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return showCalculationSwitch ? 2 : 1
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        //section 1 is toggle switch
        if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCellWithIdentifier("switch")! as! ToggleCell
            cell.hideSeparator()
            
            let data = NSUserDefaults.standardUserDefaults()
            let dict: [String : Bool] = data.dictionaryForKey(TSGradebookCalculationSettingKey) as? [String : Bool] ?? [:]
            cell.decorateWithText("Count grades with parenthesis in calculation", initialValue: dict[displayClass.ID] ?? false, handler: gradeTogglePressed)
            
            return cell
        }
        
        //section 0 are the grades
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
            cell.hideSeparator()
            return cell
        }
        
        if indexPath.item == 2 {
            let cell = tableView.dequeueReusableCellWithIdentifier("button") as! ButtonCell
            cell.decorateWithText("Add new grade", buttonImage: "button-add")
            return cell
        }
        
        let score = scores[indexPath.item - 3]
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
        if indexPath.section == 1 {
            return 60.0
        }
        
        if indexPath.item == 0 || indexPath.item == 1 && scores.count == 0 {
            return 50.0
        }
        if indexPath.item == 1 && scores.count > 0 {
            return 80.0
        }
        if indexPath.item == 2 {
            return 50.0
        }
        
        let score = scores[indexPath.item - 3]
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
    
    func loadCachedData() {
        scores = flattenedGrades(displayClass.grades) ?? []
    }
    
    func loadData() {
        scores = flattenedGrades(TSAuthenticatedReader.getGradesForClass(displayClass))
    }
    
    func flattenedGrades(grades: GradeGroup?) -> [Scored] {
        showCalculationSwitch = false
        
        guard let grades = grades else { return [] }
        let flattened = grades.flattened
        
        var totalGrades = flattened.count
        var gradesWithParenthesis = 0
        
        for score in flattened {
            if score.scoreString.hasPrefix("(") {
                gradesWithParenthesis++
            }
            else if score.scoreString == "" || score.scoreString == "COMMENT_PLACEHOLDER" {
                totalGrades--
            }
        }
        
        if gradesWithParenthesis == totalGrades {
            let data = NSUserDefaults.standardUserDefaults()
            var dict: [String : Bool] = data.dictionaryForKey(TSGradebookCalculationSettingKey) as? [String : Bool] ?? [:]
            dict[displayClass.ID] = true
            data.setValue(TSGradebookCalculationSettingKey, forKey: TSGradebookCalculationSettingKey)
            displayClass.grades?.useAllSubscores = true
        }
        else if gradesWithParenthesis > 0 {
            showCalculationSwitch = true
        }
        
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
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        if index.item == 2 { return true } //add button
        let scoreIndex = index.item - 3
        if scoreIndex >= 0 {
            let score = scores[scoreIndex]
            return score.isArtificial
        }
        return false
    }
    
    func animateSelection(cell: UITableViewCell, indexPath: NSIndexPath, selected: Bool) {
        if !canHighlightCell(indexPath) { return }
        
        var background = UIColor(white: 1.0, alpha: selected ? 0.3 : 0.0)
        
        //check if this is a category header
        let scoreIndex = indexPath.item - 3
        if scoreIndex >= 0 && scores[scoreIndex] is GradeGroup {
            background = UIColor(hue: 0.572, saturation: 0.53, brightness: 1.0, alpha: selected ? 0.0 : 0.14)
        }
        
        UIView.animateWithDuration(0.3, animations: {
            cell.backgroundColor = background
        })
    }
    
    func processSelectedCell(index: NSIndexPath) {
        if !canHighlightCell(index) { return }
        
        if index.item == 2 {
            addGradePressed()
            return
        }
        
        let scoreIndex = index.item - 3
        if scoreIndex >= 0 {
            let score = scores[scoreIndex]
            scorePressed(score)
            return
        }
    }
    
    //MARK: - User Interaction
    
    func addGradePressed() {
        
        var totalGroupWeight = 0.0
        var groupCount = 0
        for grade in displayClass.grades?.scores ?? [] {
            if let group = grade as? GradeGroup {
                totalGroupWeight += group.weight ?? 0.0
                groupCount++
            }
        }
        
        if totalGroupWeight == 100.0 {
            //there are already 100% worth of groups
            //so assume those are already in stone
            showSelectGroupDialog()
            return
        }
        
        if groupCount == 0 && scores.count != 0 {
            //there's already a grade, but no categories
            //assume we just aren't using categories
            showAddGradeDialogInRoot()
            return
        }
        
        //ask the user if they want to add a Grade or a Category
        let alert = UIAlertController(title: "Add a Grade or Category?", message: "A grade represents an assignment. A category represents a group of assignments.", preferredStyle: .Alert)
        
        alert.addAction(UIAlertAction(title: "Grade", style: .Default, handler: { _ in
            if groupCount == 0 {
                self.showAddGradeDialogInRoot()
            }
            else {
                self.showSelectGroupDialog()
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Category", style: .Default, handler: { _ in
            self.showAddCategoryDialog()
        }))
        
        alert.addAction(UIAlertAction(title: "Nevermind", style: .Destructive, handler: nil))
        controller.presentViewController(alert, animated: true, completion: nil)
    }
    
    func showSelectGroupDialog() {
        var groups: [GradeGroup] = []
        for score in scores {
            if let group = score as? GradeGroup {
                groups.append(group)
            }
        }
        
        if groups.count == 0 { showAddGradeDialogInRoot() }
        else {
            
            let alert = UIAlertController(title: "Select a Category", message: nil, preferredStyle: .Alert)
            for group in groups {
                alert.addAction(UIAlertAction(title: group.name, style: .Default, handler: { _ in
                    self.showAddGradeDialog(inGroup: group)
                }))
            }
            alert.addAction(UIAlertAction(title: "Nevermind", style: .Destructive, handler: nil))
            controller.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    func showAddGradeDialogInRoot() {
        if let grades = displayClass.grades {
            showAddGradeDialog(inGroup: grades)
        } else {
            displayClass.grades = GradeGroup(name: "ROOT", weight: 100.0)
            showAddGradeDialog(inGroup: displayClass.grades!)
        }
    }
    
    func showAddGradeDialog(inGroup group: GradeGroup, name: String? = nil) {
        
        var error = ""
        if name == "" {
            error = "You must enter a name. "
        }
        else if name != nil {
            error = "Invalid score. "
        }
        
        let alert = UIAlertController(title: "Add a Grade", message: error + "Score must be a percentage (90%) or a fraction (9/10).", preferredStyle: .Alert)
        var nameField: UITextField!
        var scoreField: UITextField!
        
        alert.addTextFieldWithConfigurationHandler({ textField in
            nameField = textField
            nameField.placeholder = "Name"
            nameField.autocapitalizationType = .Sentences
            if let name = name where name != "" {
                nameField.text = name
            }
        })
        alert.addTextFieldWithConfigurationHandler({ textField in
            scoreField = textField
            scoreField.placeholder = "Score"
        })
        
        alert.addAction(UIAlertAction(title: "Add", style: .Default, handler: { _ in
            let name = nameField.text ?? ""
            if name == "" {
                self.showAddGradeDialog(inGroup: group, name: name)
                return
            }
            
            guard var scoreString = scoreField.text else {
                self.showAddGradeDialog(inGroup: group, name: name)
                return
            }
            if !scoreString.hasSuffix("%") && !scoreString.containsString("/") {
                scoreString.appendContentsOf("%")
            }
            
            let grade = Grade(name: name, score: scoreString, weight: nil, comment: nil, isArtificial: true)
            grade.owningGroup = group.name
            if grade.score == nil {
                //couldn't parse the score
                self.showAddGradeDialog(inGroup: group, name: name)
                return
            }
            
            group.scores.append(grade)
            self.controller.resignFirstResponder()
            self.finalizeGradeChanges(add: [grade], remove: [], swap: [])
        }))
        
        controller.presentViewController(alert, animated: true, completion: nil)
    }
    
    func showAddCategoryDialog(name: String? = nil) {
        
        var error = ""
        if name == "" {
            error = "You must enter a name. "
        }
        else if name != nil {
            error = "Invalid weight. "
        }
        
        let alert = UIAlertController(title: "Add a Category", message: error + "Weight must be a percentage (90%).", preferredStyle: .Alert)
        var nameField: UITextField!
        var weightField: UITextField!
        
        alert.addTextFieldWithConfigurationHandler({ textField in
            nameField = textField
            nameField.placeholder = "Name"
            nameField.autocapitalizationType = .Sentences
            if let name = name where name != "" {
                nameField.text = name
            }
        })
        alert.addTextFieldWithConfigurationHandler({ textField in
            weightField = textField
            weightField.placeholder = "Weight"
        })
        
        alert.addAction(UIAlertAction(title: "Add", style: .Default, handler: { _ in
            let name = nameField.text ?? ""
            if name == "" {
                self.showAddCategoryDialog(name)
                return
            }
            
            guard var weightString = weightField.text else {
                self.showAddCategoryDialog(name)
                return
            }
            if !weightString.hasSuffix("%") {
                weightString.appendContentsOf("%")
            }
            
            let group = GradeGroup(name: name, weight: weightString, isArtificial: true)
            if group.weight == nil {
                //couldn't parse the weight
                self.showAddCategoryDialog(name)
                return
            }
            
            let root = self.displayClass.grades ?? GradeGroup(name: "ROOT", weight: 100.0)
            root.scores.append(group)
            self.controller.resignFirstResponder()
            self.finalizeGradeChanges(add: [group], remove: [], swap: [])
        }))
        
        controller.presentViewController(alert, animated: true, completion: nil)
        
    }
    
    func finalizeGradeChanges(add add: [Scored], remove: [Scored], swap: [(add: Scored, remove: Scored)]) {
        scores = flattenedGrades(displayClass.grades)
        controller.tableView.reloadData()
        
        let data = NSUserDefaults.standardUserDefaults()
        var dict = data.dictionaryForKey(TSCustomGradesKey) as? [String : [String]] ?? [:]
        let classKey = TSAuthenticatedReader.username + "~" + displayClass.ID
        var customScores = dict[classKey] ?? []
        
        for score in add {
            let string = score.representAsString()
            customScores.append(string)
        }
        
        for score in remove {
            let string = score.representAsString()
            if let index = customScores.indexOf(string) {
                customScores.removeAtIndex(index)
            }
        }
        
        for (add, remove) in swap {
            if let index = customScores.indexOf(remove.representAsString()) {
                customScores[index] = add.representAsString()
            } else {
                customScores.append(add.representAsString())
            }
        }
        
        dict[classKey] = customScores
        data.setValue(dict, forKey: TSCustomGradesKey)
        
    }
    
    func scorePressed(score: Scored) {
        
    }
    
    func gradeTogglePressed(newValue: Bool) {
        self.displayClass.grades?.useAllSubscores = newValue
        self.loadCachedData()
        
        delay(0.2) {
            self.controller.tableView.scrollToRowAtIndexPath(NSIndexPath(forItem: 0, inSection: 0), atScrollPosition: .Top, animated: true)
        }
        
        delay(0.6) {
            self.controller.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: UITableViewRowAnimation.Fade)
        }
        
        let data = NSUserDefaults.standardUserDefaults()
        var dict: [String : Bool] = data.dictionaryForKey(TSGradebookCalculationSettingKey) as? [String : Bool] ?? [:]
        dict[self.displayClass.ID] = newValue
        data.setValue(dict, forKey: TSGradebookCalculationSettingKey)
    }
    
}