//
//  GradebookDelegate.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 9/27/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation
import UIKit

let TSGradebookCalculationSettingKey = "edu.gatech.cal.gradebookCalculationSetting"
let TSCustomGradesKey = "edu.gatech.cal.customGrades"
let TSCachedGradesKey = "edu.gatech.cal.cachedGrades"
let TSDroppedGradesKey = "edu.gatech.cal.droppedGrades"

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
            cell.decorateWithText("Grades with parenthesis are considered dropped. Count in calculations?", initialValue: dict[displayClass.ID] ?? false, handler: gradeTogglePressed)
            
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
            cell.subjectLabel.text = "Current grade in \(displayClass.name)\(displayClass.grades?.shouldAppearAsEdited == true ? " (Edited)" : "")"
            
            //only hide seperator if scores[0] is not Grade
            if !(scores.count > 0 && scores[0] is Grade) {
                cell.hideSeparator()
            }
            
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
            cell.decorateForGradeGroup(group, inClass: displayClass)
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
            cell.decorateForScore(score, inClass: displayClass)
            let isBlank = (score.name == "" && score.scoreString == "")
            if !isBlank || (isBlank && indexPath.item - 3 == 0) {
                cell.hideSeparator()
            } else {
                cell.showSeparator()
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
        
        if let scoresInMemory = displayClass.grades {
            self.scores = flattenedGrades(scoresInMemory)
        }
        
        else {
            let cached = TSAuthenticatedReader.getCachedGradesForClass(displayClass)
            displayClass.grades = cached
            self.scores = flattenedGrades(cached)
        }

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
        return displayClass.grades == nil && !TSAuthenticatedReader.classHasCachedGrades(displayClass)
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
            
            if score is GradeGroup { return true}
            
            let isDroppable = !score.scoreString.hasPrefix("(")
            if !isDroppable { return false }
            
            let isPlaceholder = score.scoreString == "" || score.scoreString == "COMMENT_PLACEHOLDER" || score.score == nil && score is Grade
            return !isPlaceholder
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
    
    func gradeTogglePressed(newValue: Bool) {
        self.displayClass.grades?.useAllSubscores = newValue
        self.loadCachedData()
        
        let animateScrollUp = self.controller.tableView.contentOffset.y > 40.0
        let paths = [NSIndexPath(forItem: 1, inSection: 0)]
        let animation: UITableViewRowAnimation = newValue ? .Right : .Left
        
        if animateScrollUp {
            delay(0.2) {
                self.controller.tableView.scrollToRowAtIndexPath(NSIndexPath(forItem: 0, inSection: 0), atScrollPosition: .Top, animated: true)
            }
            
            delay(0.6) {
                self.controller.tableView.reloadRowsAtIndexPaths(paths, withRowAnimation: animation)
            }
        }
        
        else {
            self.controller.tableView.reloadRowsAtIndexPaths(paths, withRowAnimation: animation)
        }
        
        let data = NSUserDefaults.standardUserDefaults()
        var dict: [String : Bool] = data.dictionaryForKey(TSGradebookCalculationSettingKey) as? [String : Bool] ?? [:]
        dict[self.displayClass.ID] = newValue
        data.setValue(dict, forKey: TSGradebookCalculationSettingKey)
    }
    
    //MARK: - Adding Grades and Groups
    
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
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
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
            alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
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
        getValidGradeInput { grade in
            grade.owningGroup = group
            self.finalizeGradeChanges(add: [grade], remove: [], swap: [])
        }
    }
    
    func showAddCategoryDialog(name: String? = nil) {
        getValidGroupInput { group in
            let root = self.displayClass.grades ?? GradeGroup(name: "ROOT", weight: 100.0).asRootGroupForClass(self.displayClass)
            group.owningGroup = root
            self.finalizeGradeChanges(add: [group], remove: [], swap: [])
        }
    }
    
    //MARK: - Editing or Deleting existing scores
    
    func scorePressed(score: Scored) {
        
        if let grade = score as? Grade where !score.isArtificial {
            //authentic grades from T-Square can only be dropped and picked up
            (grade.contributesToAverage ? showDropPopupForGrade : showPickUpPopupForGrade)(grade)
            //alertFunction(grade)
            return
        }
        
        //show dialog to delete or edit if score is artificial
        let alert = UIAlertController(title: "Edit \(score is Grade ? "Grade" : "Category")", message: nil, preferredStyle: .Alert)
        
        if let group = score as? GradeGroup {
            alert.addAction(UIAlertAction(title: "Add Grade\(group.isArtificial ? "" : " to Category")", style: .Default, handler: { _ in
                self.showAddGradeDialog(inGroup: group)
            }))
        }
        
        if score.isArtificial {
            alert.addAction(UIAlertAction(title: "Edit", style: .Default, handler: editScoreHandler(score)))
            alert.addAction(UIAlertAction(title: "Delete", style: .Destructive, handler: deleteScoreHandler(score)))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        controller.presentViewController(alert, animated: true, completion: nil)
    }
    
    func deleteScoreHandler(score: Scored) -> (UIAlertAction) -> () {
        return { _ in
            
            var toRemove = [score]
            if let group = score as? GradeGroup {
                toRemove.appendContentsOf(group.scores)
            }
            
            self.finalizeGradeChanges(add: [], remove: toRemove, swap: [])
        }
    }
    
    func editScoreHandler(score: Scored) -> (UIAlertAction) -> () {
        return { _ in
            
            func closure(var new: Scored) {
                new.owningGroup = score.owningGroup
                self.finalizeGradeChanges(add: [], remove: [], swap: [(new, score)])
            }
            
            if score is Grade {
                self.getValidGradeInput(score.name, completion: closure)
            } else {
                self.getValidGroupInput(score.name, completion: closure)
            }
            
        }
    }
    
    //MARK: - Validate and Finalize changes
    
    func finalizeGradeChanges(var add add: [Scored], var remove: [Scored], swap: [(add: Scored, remove: Scored)]) {
        let data = NSUserDefaults.standardUserDefaults()
        var dict = data.dictionaryForKey(TSCustomGradesKey) as? [String : [String]] ?? [:]
        let classKey = TSAuthenticatedReader.username + "~" + displayClass.ID
        var customScores = dict[classKey] ?? []
        
        for (addScore, removeScore) in swap {
            
            if let removeGroup = removeScore as? GradeGroup, let addGroup = addScore as? GradeGroup {
                for var score in removeGroup.scores {
                    remove.append(score)
                    add.append(score)
                    score.owningGroup = addGroup
                }
            }
            
            if let removeIndex = removeScore.owningGroup?.scores.indexOf(equalityFunctionForScore(removeScore)) {
                removeScore.owningGroup?.scores[removeIndex] = addScore
            }
            
            if let index = customScores.indexOf(removeScore.representAsString()) {
                customScores[index] = addScore.representAsString()
            } else {
                customScores.append(addScore.representAsString())
            }
        }
        
        for score in remove {
            if let index = score.owningGroup?.scores.indexOf(equalityFunctionForScore(score)) {
                score.owningGroup?.scores.removeAtIndex(index)
            }
            
            let string = score.representAsString()
            if let index = customScores.indexOf(string) {
                customScores.removeAtIndex(index)
            }
        }
        
        for score in add {
            score.owningGroup?.scores.append(score)
            
            let string = score.representAsString()
            customScores.append(string)
        }
        
        dict[classKey] = customScores
        data.setValue(dict, forKey: TSCustomGradesKey)
        
        //update on screen
        scores = flattenedGrades(displayClass.grades)
        controller.tableView.reloadData()
    }
    
    func getValidGradeInput(initialName: String? = nil, completion: (Grade) -> ()) {
        let title = "\(initialName != nil ? "Edit" : "Add") a Grade"
        self.showDialogForMultipleInputWithTitle(title, shouldAllowFractions: true, previousNameInput: initialName, performingEdit: initialName != nil, completion: { name, scoreInput in
            
            var scoreString = scoreInput
            if !scoreString.containsString("/") && !scoreString.hasSuffix("%") {
                scoreString.appendContentsOf("%")
            }
            
            let grade = Grade(name: name, score: scoreString, weight: nil, comment: nil, isArtificial: true)
            if grade.score == nil {
                //couldn't parse the score
                return false
            }
            
            completion(grade)
            return true
        })
        
    }
    
    func getValidGroupInput(initialName: String? = nil, completion: (GradeGroup) -> ()) {
        let title = "\(initialName != nil ? "Edit" : "Add") a Category"
        self.showDialogForMultipleInputWithTitle(title, shouldAllowFractions: false, previousNameInput: initialName, performingEdit: initialName != nil, completion: { name, weightInput in
            
            var weightString = weightInput
            if !weightString.hasSuffix("%") {
                weightString.appendContentsOf("%")
            }
            
            let group = GradeGroup(name: name, weight: weightString, isArtificial: true)
            if group.weight == nil {
                //couldn't parse the weight
                return false
            }
            
            completion(group)
            return true
        })
    }
    
    func showDialogForMultipleInputWithTitle(title: String, shouldAllowFractions: Bool, previousNameInput: String? = nil, performingEdit: Bool = false, completion: (String, String) -> (Bool)) {
        var error = ""
        if previousNameInput == "" {
            error = "You must enter a name. "
        }
        else if previousNameInput != nil && !performingEdit {
            error = "Invalid score. "
        }
        
        let message = error + "Score must be a percentage (90%)" + (shouldAllowFractions ? " or a fraction (9/10)" : "") + "."
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        var nameField: UITextField!
        var scoreField: UITextField!
        
        alert.addTextFieldWithConfigurationHandler({ textField in
            nameField = textField
            nameField.placeholder = "Name"
            nameField.autocapitalizationType = .Sentences
            if let name = previousNameInput where name != "" {
                nameField.text = name
            }
        })
        alert.addTextFieldWithConfigurationHandler({ textField in
            scoreField = textField
            scoreField.keyboardType = UIKeyboardType.NumbersAndPunctuation
            scoreField.placeholder = shouldAllowFractions ? "Score" : "Weight"
        })
        
        alert.addAction(UIAlertAction(title: performingEdit ? "Save" : "Add", style: .Default, handler: { _ in
            let name = nameField.text ?? ""
            if name == "" {
                self.showDialogForMultipleInputWithTitle(title, shouldAllowFractions: shouldAllowFractions, previousNameInput: name, completion: completion)
                return
            }
            
            guard let scoreString = scoreField.text else {
                self.showDialogForMultipleInputWithTitle(title, shouldAllowFractions: shouldAllowFractions, previousNameInput: name, completion: completion)
                return
            }
            
            let success = completion(name, scoreString)
            if !success {
                self.showDialogForMultipleInputWithTitle(title, shouldAllowFractions: shouldAllowFractions, previousNameInput: name, completion: completion)
            }
            else {
                self.controller.resignFirstResponder()
            }
            
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        controller.presentViewController(alert, animated: true, completion: nil)
        
        delay(0.1) {
            if nameField.text != "" {
                scoreField.becomeFirstResponder()
            }
        }
        
    }
    
    //MARK: - Dropping and Undropping grades from T-Square
    
    func showDropPopupForGrade(grade: Grade) {
        let alert = UIAlertController(title: "Drop grade?", message: "This grade would no longer contribute to your average.", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Drop", style: .Default, handler: { _ in
            self.setDropStatus(true, forGrade: grade)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        controller.presentViewController(alert, animated: true, completion: nil)
    }
    
    func showPickUpPopupForGrade(grade: Grade) {
        let alert = UIAlertController(title: "Pick up grade?", message: "This grade would contribute to your average again.", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Pick up", style: .Default, handler: { _ in
            self.setDropStatus(false, forGrade: grade)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        controller.presentViewController(alert, animated: true, completion: nil)
    }
    
    func setDropStatus(dropped: Bool, forGrade grade: Grade) {
        //update in memory
        grade.contributesToAverage = !dropped
        
        //update on disk
        let data = NSUserDefaults.standardUserDefaults()
        var dict = data.dictionaryForKey(TSDroppedGradesKey) as? [String : [String]] ?? [:]
        let classKey = TSAuthenticatedReader.username + "~" + displayClass.ID
        var droppedScores = dict[classKey] ?? []
        
        if grade.contributesToAverage {
            //remove from array
            if let index = droppedScores.indexOf(grade.representAsString()) {
                droppedScores.removeAtIndex(index)
            }
        } else {
            //add to array
            droppedScores.append(grade.representAsString())
        }
        
        dict[classKey] = droppedScores
        data.setValue(dict, forKey: TSDroppedGradesKey)
        
        //update on screen
        scores = flattenedGrades(displayClass.grades)
        controller.tableView.reloadData()
    }
    
}
