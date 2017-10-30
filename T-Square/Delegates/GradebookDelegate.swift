//
//  GradebookDelegate.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 9/27/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation
import UIKit
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


let TSGradebookCalculationSettingKey = "edu.gatech.cal.gradebookCalculationSetting"
let TSCustomGradesKey = "edu.gatech.cal.customGrades"
let TSCachedGradesKey = "edu.gatech.cal.cachedGrades"
let TSDroppedGradesKey = "edu.gatech.cal.droppedGrades"
let TSManualCategoryWeightsKey = "edu.gatech.cal.manualCategoryWeight"

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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 { return 1 }
        return 2 + (scores.count == 0 ? 1 : scores.count + 1)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return showCalculationSwitch ? 2 : 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        //section 1 is toggle switch
        if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "switch")! as! ToggleCell
            cell.hideSeparator()
            
            let data = UserDefaults.standard
            let dict: [String : Bool] = data.dictionary(forKey: TSGradebookCalculationSettingKey) as? [String : Bool] ?? [:]
            cell.decorateWithText("Grades with parenthesis are considered dropped. Count in calculations?", initialValue: dict[displayClass.permanentID] ?? false, handler: gradeTogglePressed)
            
            return cell
        }
        
        //section 0 are the grades
        if indexPath.item == 0 {
            return tableView.dequeueReusableCell(withIdentifier: "back")!
        }
        if indexPath.item == 1 && (scores.count == 0 || scores.count == 1) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "standardTitle")! as! TitleCell
            cell.decorate("Nothing here yet.")
            return cell
        }
        if indexPath.item == 1 && scores.count != 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "classTitle") as! ClassNameCell
            cell.nameLabel.text = displayClass.grades?.scoreString ?? "-"
            
            let score = displayClass.grades?.score
            
            cell.subjectLabel.text = "Grade in \(displayClass.name)"
            if score > 0.9 {
                cell.subjectLabel.text = "🎉 \(cell.subjectLabel.text!)"
            }
            if let fractionScore = displayClass.grades?.fractionString {
                cell.subjectLabel.text = "\(cell.subjectLabel.text!) (\(fractionScore))"
            }
            if displayClass.grades?.shouldAppearAsEdited == true {
                cell.subjectLabel.text = "\(cell.subjectLabel.text!) (Edited)"
            }
            
            //only hide seperator if scores[0] is not Grade
            if !(scores.count > 0 && scores[0] is Grade) {
                cell.hideSeparator()
            }
            
            return cell
        }
        
        if indexPath.item == 2 {
            let whatIf: String? = (displayClass.grades?.scores.count > 0) == true ? " (what if)" : nil
            let cell = tableView.dequeueReusableCell(withIdentifier: "button") as! ButtonCell
            cell.decorateWithText("Add new grade" + (whatIf ?? ""), buttonImage: "button-add")
            
            if let whatIf = whatIf {
                //make an attributed string
                let base = NSMutableAttributedString(string: "Add new grade")
                let whatIfAttr = NSMutableAttributedString(string: whatIf)
                whatIfAttr.addAttribute(NSForegroundColorAttributeName, value: UIColor(white: 0.0, alpha: 0.25), range: NSMakeRange(0, whatIf.length))
                
                base.append(whatIfAttr)
                cell.label?.attributedText = base
            }
            
            return cell
        }
        
        let score = scores[indexPath.item - 3]
        if let group = score as? GradeGroup {
            let cell = tableView.dequeueReusableCell(withIdentifier: "gradeGroup")! as! GradeGroupCell
            cell.decorateForGradeGroup(group, inClass: displayClass)
            return cell
        }
        else {
            if score.scoreString == "COMMENT_PLACEHOLDER" {
                let cell = tableView.dequeueReusableCell(withIdentifier: "gradeComment")! as! TitleCell
                cell.decorate(score.name)
                cell.hideSeparator()
                return cell
            }
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "grade")! as! GradeCell
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
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
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
                let font = UIFont.systemFont(ofSize: 15.0)
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
        displayClass.grades?.scoreString //calculate the score so any lingering configuration will be present
    }
    
    func flattenedGrades(_ grades: GradeGroup?) -> [Scored] {
        showCalculationSwitch = false
        
        guard let grades = grades else { return [] }
        let flattened = grades.flattened
        
        var totalGrades = flattened.count
        var gradesWithParenthesis = 0
        
        for score in flattened {
            if score.scoreString.hasPrefix("(") {
                gradesWithParenthesis += 1
            }
            else if score.scoreString == "" || score.scoreString == "COMMENT_PLACEHOLDER" {
                totalGrades -= 1
            }
        }
        
        if gradesWithParenthesis == totalGrades {
            let data = UserDefaults.standard
            var dict: [String : Bool] = data.dictionary(forKey: TSGradebookCalculationSettingKey) as? [String : Bool] ?? [:]
            dict[displayClass.permanentID] = true
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
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: TSSetTouchDelegateEnabledNotification), object: false)
        delay(0.5) {
            NotificationCenter.default.post(name: Notification.Name(rawValue: TSSetTouchDelegateEnabledNotification), object: true)
        }
    }
    
    func canHighlightCell(_ index: IndexPath) -> Bool {
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
    
    func animateSelection(_ cell: UITableViewCell, indexPath: IndexPath, selected: Bool) {
        if !canHighlightCell(indexPath) { return }
        
        var background = UIColor(white: 1.0, alpha: selected ? 0.3 : 0.0)
        
        //check if this is a category header
        let scoreIndex = indexPath.item - 3
        if scoreIndex >= 0 && scores[scoreIndex] is GradeGroup {
            background = UIColor(hue: 0.572, saturation: 0.53, brightness: 1.0, alpha: selected ? 0.0 : 0.14)
        }
        
        UIView.animate(withDuration: 0.3, animations: {
            cell.backgroundColor = background
        })
    }
    
    func processSelectedCell(_ index: IndexPath) {
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
    
    func gradeTogglePressed(_ newValue: Bool) {
        
        let animateScrollUp = self.controller.tableView.contentOffset.y > 40.0
        let paths = [IndexPath(item: 1, section: 0)]
        let animation: UITableViewRowAnimation = newValue ? .right : .left
        
        if animateScrollUp {
            delay(0.2) {
                self.controller.tableView.scrollToRow(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
            }
            
            delay(0.6) {
                self.displayClass.grades?.useAllSubscores = newValue
                self.loadCachedData()
                
                self.controller.tableView.reloadRows(at: paths, with: animation)
            }
        }
        
        else {
            self.controller.tableView.reloadRows(at: paths, with: animation)
        }
        
        let data = UserDefaults.standard
        var dict: [String : Bool] = data.dictionary(forKey: TSGradebookCalculationSettingKey) as? [String : Bool] ?? [:]
        dict[self.displayClass.permanentID] = newValue
        data.setValue(dict, forKey: TSGradebookCalculationSettingKey)
    }
    
    //MARK: - Adding Grades and Groups
    
    func addGradePressed() {
        
        var totalGroupWeight = 0.0
        var groupCount = 0
        for grade in displayClass.grades?.scores ?? [] {
            if let group = grade as? GradeGroup {
                totalGroupWeight += group.weight ?? 0.0
                groupCount += 1
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
        let alert = UIAlertController(title: "Add a Grade or Category?", message: "A grade represents an assignment. A category represents a group of assignments.", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Grade", style: .default, handler: { _ in
            if groupCount == 0 {
                self.showAddGradeDialogInRoot()
            }
            else {
                self.showSelectGroupDialog()
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Category", style: .default, handler: { _ in
            self.showAddCategoryDialog()
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        controller.present(alert, animated: true, completion: nil)
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
            
            let alert = UIAlertController(title: "Select a Category", message: nil, preferredStyle: .alert)
            for group in groups {
                alert.addAction(UIAlertAction(title: group.name, style: .default, handler: { _ in
                    self.showAddGradeDialog(inGroup: group)
                }))
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            controller.present(alert, animated: true, completion: nil)
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
    
    func showAddCategoryDialog(_ name: String? = nil) {
        getValidGroupInput { group in
            let root = self.displayClass.grades ?? GradeGroup(name: "ROOT", weight: 100.0).asRootGroupForClass(self.displayClass)
            group.owningGroup = root
            self.finalizeGradeChanges(add: [group], remove: [], swap: [])
        }
    }
    
    //MARK: - Editing or Deleting existing scores
    
    func scorePressed(_ score: Scored) {
        
        if let grade = score as? Grade, !score.isArtificial {
            //authentic grades from T-Square can only be dropped and picked up
            (grade.contributesToAverage ? showDropPopupForGrade : showPickUpPopupForGrade)(grade)
            //alertFunction(grade)
            return
        }
        
        //show dialog to delete or edit if score is artificial
        let alert = UIAlertController(title: "Edit \(score is Grade ? "Grade" : "Category")", message: nil, preferredStyle: .alert)
        
        if let group = score as? GradeGroup {
            
            alert.addAction(UIAlertAction(title: "Add Grade\(group.isArtificial ? "" : " to Category")", style: .default, handler: { _ in
                self.showAddGradeDialog(inGroup: group)
            }))
            
            if !group.isArtificial {
                let title = (group.weight == nil || group.weight == 0.0) ? "Add Weight" : "Edit Weight"
                alert.addAction(UIAlertAction(title: title, style: .default, handler: editScoreHandler(score, completion: { newScore in
                    if let newCategory = newScore as? GradeGroup {
                        self.setManualWeightForGroup(newCategory, weight: newCategory.weight ?? 0.0)
                    }
                })))
                
                if title == "Edit Weight" {
                    alert.addAction(UIAlertAction(title: "Remove Weight", style: .default, handler: { _ in
                        self.setManualWeightForGroup(group, weight: 0.0)
                        let newGroup = GradeGroup(name: group.name, weight: nil, isArtificial: false)
                        newGroup.owningGroup = group.owningGroup
                        self.finalizeGradeChanges(add: [], remove: [], swap: [(newGroup, group)])
                    }))
                }
            }
            
        }
        
        if score.isArtificial {
            alert.addAction(UIAlertAction(title: "Edit", style: .default, handler: editScoreHandler(score)))
            
            if let grade = score as? Grade {
                alert.addAction(UIAlertAction(title: grade.contributesToAverage ? "Drop" : "Pick Up", style: .default, handler: { _ in
                    self.setDropStatus(grade.contributesToAverage, forGrade: grade)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: deleteScoreHandler(score)))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        controller.present(alert, animated: true, completion: nil)
    }
    
    func deleteScoreHandler(_ score: Scored) -> (UIAlertAction) -> () {
        return { _ in
            
            var toRemove = [score]
            if let group = score as? GradeGroup {
                toRemove.append(contentsOf: group.scores)
            }
            
            self.finalizeGradeChanges(add: [], remove: toRemove, swap: [])
        }
    }
    
    func editScoreHandler(_ score: Scored, completion: ((Scored) -> ())? = nil) -> (UIAlertAction) -> () {
        return { _ in
            
            func closure(_ newScore: Scored) {
                var new = newScore
                new.owningGroup = score.owningGroup
                self.finalizeGradeChanges(add: [], remove: [], swap: [(new, score)])
                completion?(new)
            }
            
            if score is Grade {
                self.getValidGradeInput(score.name, completion: closure)
            } else {
                self.getValidGroupInput(score.name, canEditName: score.isArtificial, completion: closure)
            }
            
        }
    }
    
    func setManualWeightForGroup(_ group: GradeGroup, weight: Double) {
        let data = UserDefaults.standard
        var dict = data.dictionary(forKey: TSManualCategoryWeightsKey) as? [String : Double] ?? [:]
        let key = "\(TSAuthenticatedReader.username)~\(self.displayClass.permanentID)~\(group.name)"
        dict.updateValue(weight, forKey: key)
        data.setValue(dict, forKey: TSManualCategoryWeightsKey)
    }
    
    //MARK: - Validate and Finalize changes
    
    func finalizeGradeChanges(add addScores: [Scored], remove removeScores: [Scored], swap: [(add: Scored, remove: Scored)]) {
        var add = addScores
        var remove = removeScores
        
        let data = UserDefaults.standard
        var dict = data.dictionary(forKey: TSCustomGradesKey) as? [String : [String]] ?? [:]
        let classKey = TSAuthenticatedReader.username + "~" + displayClass.permanentID
        var customScores = dict[classKey] ?? []
        
        //make a list of all the scores being edited
        var allScores: [Scored] = []
        allScores.append(contentsOf: add)
        allScores.append(contentsOf: remove)
        for (add, remove) in swap {
            allScores.append(add)
            allScores.append(remove)
        }
        //make sure the owning group of any grade is that group from the current root
        //(because we swap out the root after loading from the server)
        for score in allScores {
            if let grade = score as? Grade,
               let currentOwner = grade.owningGroup {
                if let indexInRoot = displayClass.grades?.scores.index(where: equalityFunctionForScore(currentOwner)) {
                    let groupInRoot = displayClass.grades!.scores[indexInRoot] as! GradeGroup
                    grade.owningGroup = groupInRoot
                }
            }
        }
        
        //swap grades with new versions
        for (addScore, removeScore) in swap {
            
            if let removeGroup = removeScore as? GradeGroup, let addGroup = addScore as? GradeGroup {
                
                for var score in removeGroup.scores {
                    if addGroup.isArtificial {
                        remove.append(score)
                        add.append(score)
                    } else {
                        addGroup.scores.append(score)
                    }
                    score.owningGroup = addGroup
                }
            }
            
            let owner = removeScore.owningGroup?.name == "ROOT" ? displayClass.grades : removeScore.owningGroup
            if let removeIndex = owner?.scores.index(where: equalityFunctionForScore(removeScore)) {
                owner?.scores[removeIndex] = addScore
            }
            
            if addScore.isArtificial {
                if let index = customScores.index(of: removeScore.representAsString()) {
                    customScores[index] = addScore.representAsString()
                } else {
                    customScores.append(addScore.representAsString())
                }
            }
            
        }
        
        //remove grades
        for score in remove {
            if let index = score.owningGroup?.scores.index(where: equalityFunctionForScore(score)) {
                score.owningGroup?.scores.remove(at: index)
            }
            
            let string = score.representAsString()
            if let index = customScores.index(of: string) {
                customScores.remove(at: index)
            }
        }
        
        //add grades
        for score in add {
            score.owningGroup?.scores.append(score)
            
            let string = score.representAsString()
            customScores.append(string)
        }
        
        //recalculate total score and all lingering configuration
        displayClass.grades?.scoreString
        
        //save to disk
        //(we specifically save *after* recalculating the score,
        // because if the user does something that causes it to crash, like an integer overflow,
        // that number would get saved to disk and cause it to crash every time in the future)
        dict[classKey] = customScores
        data.setValue(dict, forKey: TSCustomGradesKey)
        
        //update on screen
        scores = flattenedGrades(displayClass.grades)
        controller.tableView.reloadData()
    }
    
    func getValidGradeInput(_ initialName: String? = nil, completion: @escaping (Grade) -> ()) {
        let title = "\(initialName != nil ? "Edit" : "Add") a Grade"
        self.showDialogForMultipleInputWithTitle(title, shouldAllowFractions: true, previousNameInput: initialName, performingEdit: initialName != nil, completion: { name, scoreInput in
            
            var scoreString = scoreInput
            if !scoreString.contains("/") && !scoreString.hasSuffix("%") {
                scoreString.append("%")
            }
            
            let grade = Grade(name: name, score: scoreString, weight: nil, comment: nil, isArtificial: true)
            if grade.score == nil {
                //couldn't parse the score
                return false
            }
            
            //prevent an integer overflow
            if grade.score > Double(Int.max) {
                return false
            }
            
            completion(grade)
            return true
        })
        
    }
    
    func getValidGroupInput(_ initialName: String? = nil, canEditName: Bool = true, completion: @escaping (GradeGroup) -> ()) {
        let title = "\(initialName != nil ? "Edit" : "Add") a Category"
        self.showDialogForMultipleInputWithTitle(title, shouldAllowFractions: false, previousNameInput: initialName, performingEdit: initialName != nil, canEditName: canEditName, completion: { name, weightInput in
            
            var weightString = weightInput
            if !weightString.hasSuffix("%") {
                weightString.append("%")
            }
            
            let group = GradeGroup(name: name, weight: weightString, isArtificial: canEditName, inClass: self.displayClass)
            if group.weight == nil {
                //couldn't parse the weight
                return false
            }
            
            completion(group)
            return true
        })
    }
    
    func showDialogForMultipleInputWithTitle(_ title: String, shouldAllowFractions: Bool, previousNameInput: String? = nil, performingEdit: Bool = false, canEditName: Bool = true, completion: @escaping (String, String) -> (Bool)) {
        
        let inputNumberName = shouldAllowFractions ? "Score" : "Weight"
        
        var error = ""
        if previousNameInput == "" {
            error = "You must enter a name. "
        }
        else if previousNameInput != nil && !performingEdit {
            error = "Invalid \(inputNumberName.lowercased()). "
        }
        
        let message = error + "\(inputNumberName) must be a percentage (90%)" + (shouldAllowFractions ? " or a fraction (9/10)" : "") + "."
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        var nameField: UITextField!
        var scoreField: UITextField!
        
        alert.addTextField(configurationHandler: { textField in
            nameField = textField
            nameField.placeholder = "Name"
            nameField.autocapitalizationType = .sentences
            if let name = previousNameInput, name != "" {
                nameField.text = name
            }
            
            if !canEditName {
                nameField.isEnabled = false
                nameField.textColor = UIColor.gray
            }
            
        })
        alert.addTextField(configurationHandler: { textField in
            scoreField = textField
            scoreField.keyboardType = UIKeyboardType.numbersAndPunctuation
            scoreField.placeholder = inputNumberName
        })
        
        alert.addAction(UIAlertAction(title: performingEdit ? "Save" : "Add", style: .default, handler: { _ in
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
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        controller.present(alert, animated: true, completion: nil)
        
        delay(0.1) {
            if nameField.text != "" {
                scoreField.becomeFirstResponder()
            }
        }
        
    }
    
    //MARK: - Dropping and Undropping grades from T-Square
    
    func showDropPopupForGrade(_ grade: Grade) {
        let alert = UIAlertController(title: "Drop grade?", message: "This grade would no longer contribute to your average.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Drop", style: .default, handler: { _ in
            self.setDropStatus(true, forGrade: grade)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        controller.present(alert, animated: true, completion: nil)
    }
    
    func showPickUpPopupForGrade(_ grade: Grade) {
        let alert = UIAlertController(title: "Pick up grade?", message: "This grade would contribute to your average again.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Pick up", style: .default, handler: { _ in
            self.setDropStatus(false, forGrade: grade)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        controller.present(alert, animated: true, completion: nil)
    }
    
    func setDropStatus(_ dropped: Bool, forGrade grade: Grade) {
        //update in memory
        grade.contributesToAverage = !dropped
        
        //update on disk
        let data = UserDefaults.standard
        var dict = data.dictionary(forKey: TSDroppedGradesKey) as? [String : [String]] ?? [:]
        let classKey = TSAuthenticatedReader.username + "~" + displayClass.permanentID
        var droppedScores = dict[classKey] ?? []
        
        if grade.contributesToAverage {
            //remove from array
            if let index = droppedScores.index(of: grade.representAsString()) {
                droppedScores.remove(at: index)
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
