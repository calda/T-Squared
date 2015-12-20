//
//  TableViewCells.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 9/1/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation
import UIKit

class ClassNameCell : UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var subjectLabel: UILabel!
    
    func decorate(displayClass: Class) {
        nameLabel.text = displayClass.name
        subjectLabel.text = displayClass.subjectName ?? ""
        displayClass.displayCell = self
    }
    
}

class ClassNameCellWithIcon : ClassNameCell {
    
    @IBOutlet weak var icon: UIImageView!
    
    override func decorate(displayClass: Class) {
        super.decorate(displayClass)
        self.icon.image = UIImage(named: displayClass.subjectIcon)?.imageWithRenderingMode(.AlwaysTemplate)
        self.icon.tintColor = UIColor.blackColor()
    }
    
}

class ClassNameCellWithSwitch : ClassNameCellWithIcon {
    
    @IBOutlet weak var toggleSwitch: UISwitch!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    var displayClass: Class?
    var preferencesLink: String?
    var controller: ClassesViewController?
    
    func decorate(displayClass: Class, preferencesLink: String?, controller: ClassesViewController) {
        self.displayClass = displayClass
        self.preferencesLink = preferencesLink
        self.controller = controller
        
        super.decorate(displayClass)
        self.toggleSwitch.on = displayClass.isActive
        
        //if there is a toggle in the queue
        if let index = ClassNameCellWithSwitch.activeToggleQueue.indexOf({ return $0.displayClass == displayClass }) {
            let (_, newStatus, _, _) = ClassNameCellWithSwitch.activeToggleQueue[index]
            self.toggleSwitch.on = newStatus
            self.toggleSwitch.alpha = 0.0
            self.activityIndicator.alpha = 1.0
            self.activityIndicator.startAnimating()
        }
        
        self.toggleSwitch.hidden = preferencesLink == nil
    }
    
    @IBAction func switchToggled(sender: UISwitch) {
        if let preferencesLink = preferencesLink,
           let displayClass = displayClass,
           let controller = controller {
            
            let newStatus = sender.on
            
            //animate indicator visible
            self.activityIndicator.startAnimating()
            UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
                self.activityIndicator.alpha = 1.0
                self.toggleSwitch.alpha = 0.0
            }, completion: nil)
            
            ClassNameCellWithSwitch.activeToggleQueue.append((displayClass: displayClass, newStatus: newStatus, activityIndicator: activityIndicator, toggleSwitch: toggleSwitch))
            if ClassNameCellWithSwitch.activeToggleQueue.count == 1 {
                ClassNameCellWithSwitch.performActiveToggle(displayClass, newStatus: newStatus, preferencesLink: preferencesLink, controller: controller, activityIndicator: activityIndicator, toggleSwitch: toggleSwitch)
            }
            
            displayClass.isActive = newStatus
            
        } else {
            sender.on = !sender.on
        }
        
    }
    
    static var activeToggleQueue: [(displayClass: Class, newStatus: Bool, activityIndicator: UIActivityIndicatorView?, toggleSwitch: UISwitch?)] = []
    
    static func performActiveToggle(displayClass: Class, newStatus: Bool, preferencesLink: String, controller: ClassesViewController,
        activityIndicator: UIActivityIndicatorView?, toggleSwitch: UISwitch?) {
            
        //make network call
        NSNotificationCenter.defaultCenter().postNotificationName(TSPerformingNetworkActivityNotification, object: true)
        dispatch_async(TSNetworkQueue) {
            
            HttpClient.markClassActive(displayClass, active: newStatus, atPreferencesLink: preferencesLink)
            
            sync {
                NSNotificationCenter.defaultCenter().postNotificationName(TSPerformingNetworkActivityNotification, object: false)
                //animate switch visible
                UIView.animateWithDuration(0.8, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
                    activityIndicator?.alpha = 0.0
                    toggleSwitch?.alpha = 1.0
                }, completion: { _ in
                        activityIndicator?.stopAnimating()
                })
                
                //add or remove from arrays representing active classes
                if newStatus && controller.classes?.contains(displayClass) == false {
                    controller.classes?.append(displayClass)
                    TSAuthenticatedReader.classes?.append(displayClass)
                } else {
                    if let index = controller.classes?.indexOf(displayClass) {
                        controller.classes?.removeAtIndex(index)
                    }
                    if let index = TSAuthenticatedReader.classes?.indexOf(displayClass) {
                        TSAuthenticatedReader.classes?.removeAtIndex(index)
                    }
                }
                
                //reload if the user already went back to the Classes View Controller
                if controller.tableView.delegate is ClassesViewController {
                    controller.reloadTable()
                }
                
                //done, pull from queue and continue with next
                if let index = activeToggleQueue.indexOf({ return $0.displayClass == displayClass }) {
                    activeToggleQueue.removeAtIndex(index)
                }
                
                if activeToggleQueue.count > 0 {
                    if let (nextDisplayClass, nextNewStatus, newActivityIndicator, newToggleSwitch) = activeToggleQueue.first {
                        performActiveToggle(nextDisplayClass, newStatus: nextNewStatus, preferencesLink: preferencesLink, controller: controller, activityIndicator: newActivityIndicator, toggleSwitch: newToggleSwitch)
                    }
                }
                
            }
        }

    }
    
}

class AnnouncementCell : UITableViewCell {
    
    var announcement: Announcement!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    static var originalDescriptionText: NSAttributedString?
    
    func decorate(announcement: Announcement) {
        self.announcement = announcement
        
        if AnnouncementCell.originalDescriptionText == nil {
            AnnouncementCell.originalDescriptionText = descriptionLabel.attributedText
        }
        
        titleLabel.text = announcement.name
        
        if !announcement.hasBeenRead() {
            titleLabel.text = "⭐️ \(titleLabel.text!)"
        }
        
        //decorate label with time
        let timeAgo = announcement.date?.agoString() ?? announcement.rawDateString
        let className = announcement.owningClass.name
        let attributed = AnnouncementCell.originalDescriptionText?.mutableCopy() as? NSMutableAttributedString
            ?? descriptionLabel.attributedText!.mutableCopy() as! NSMutableAttributedString
        attributed.replaceCharactersInRange(NSMakeRange(18, 8), withString: className)
        attributed.replaceCharactersInRange(NSMakeRange(0, 14), withString: timeAgo)
        descriptionLabel.attributedText = attributed
    }
    
    static func presentAnnouncement(announcement: Announcement, inController controller: ClassesViewController) {
        let delegate = AnnouncementDelegate(announcement: announcement, controller: controller)
        delegate.loadDataAndPushInController(controller)
    }
    
}

class TitleCell : UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    func decorate(text: String) {
        titleLabel.text = text
    }
    
}

class TitleWithButtonCell : BackCell {
    
    
    @IBOutlet weak var button: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    
    func decorate(text: String, buttonText: String, activityIndicatorHidden: Bool) {
        titleLabel.text = text
        button.text = buttonText
        activityIndicator.hidden = activityIndicatorHidden
    }
    
}

class AttachmentCell : TitleCell {
    
    @IBOutlet weak var background: UIView!
    
    override func decorate(text: String) {
        super.decorate(text)
        background.layer.cornerRadius = 5.0
        background.layer.masksToBounds = true
    }
    
    static func presentAttachment(attachment: Attachment, inController controller: ClassesViewController) {
        if let link = attachment.link?.preparedForURL(isFullURL: true), let url = NSURL(string: link) {
            controller.presentDocumentFromURL(url)
        }
        
        else if let rawText = attachment.rawText {
            controller.openTextInWebView(rawText, title: attachment.fileName)
        }
    }
    
    static func presentResource(resource: Resource, inController controller: ClassesViewController) {
        if let url = NSURL(string: resource.link) {
            controller.presentDocumentFromURL(url)
        }
    }
    
}

class AssignmentCell : UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dueLabel: UILabel!
    
    func decorate(assignment: Assignment) {
        titleLabel.text = assignment.name
        
        dueLabel.textColor = UIColor.blackColor()
        dueLabel.alpha = 0.5
        if assignment.completed {
            dueLabel.text = "✔︎ Completed"
            dueLabel.textColor = UIColor(red: 0.0, green: 0.3, blue: 0.0, alpha: 1.0)
            return
        }
        
        if let date = assignment.dueDate {
            dueLabel.text = "Due \(date.agoString())"
            if (dueLabel.text!.containsString("hour") || dueLabel.text!.containsString("minute")) || date.timeIntervalSinceNow < 0 {
                titleLabel.text = "⚠️ \(assignment.name)"
                dueLabel.alpha = 0.7
                dueLabel.textColor = UIColor(red: 0.5, green: 0.0, blue: 0.0, alpha: 1.0)
            }
        }
        else {
            dueLabel.text = "Due \(assignment.rawDueDateString)"
        }
    }
    
}

class GradeGroupCell : UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var weightLabel: UILabel!
    @IBOutlet weak var editButton: UIImageView!
    
    @IBOutlet weak var titleLabelPosition: NSLayoutConstraint!
    @IBOutlet weak var editButtonHeight: NSLayoutConstraint!
    
    func decorateForGradeGroup(group: GradeGroup, inClass displayClass: Class) {
        titleLabel.text = group.name
        scoreLabel.text = group.scoreString
        weightLabel.text = nil
        
        if displayClass.grades?.ignoreSubgroupScores == true {
            scoreLabel.text = ""
        } else if group.weight == nil || group.weight == 0.0 {
            scoreLabel.text = ""
            weightLabel.text = "Excluded from average (not weighted, tap to edit)"
        }
        
        if let weight = group.weight where weight != 0.0 {
            weightLabel.text = "Weight: \(Int(weight))%"
        }
        
        if weightLabel.text != nil {
            weightLabel.alpha = 0.5
            titleLabelPosition.constant = -10.0
            titleLabel.baselineAdjustment = .AlignBaselines
        }
        else {
            weightLabel.alpha = 0.0
            titleLabelPosition.constant = 0
            titleLabel.baselineAdjustment = .AlignCenters
        }
        
        editButton.hidden = !group.isArtificial
        if !editButton.hidden {
            editButton.alpha = displayClass.grades?.shouldAppearAsEdited == true ? 1.0 : 0.3
            editButtonHeight.constant = 0
        } else {
            editButtonHeight.constant = -17.5 //make it basically disappear
        }
        
        self.layoutIfNeeded()
    }
    
}

class GradeCell : UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var editButton: UIImageView!
    
    func decorateForScore(grade: Scored, inClass displayClass: Class) {
        let name = grade.name.cleansed()
        let scoreString = grade.scoreString
        
        titleLabel.text = name
        scoreLabel.text = scoreString
        editButton.alpha = 0.0
        
        editButton.hidden = !grade.isArtificial
        editButton.alpha = displayClass.grades?.shouldAppearAsEdited == true ? 1.0 : 0.3
        
        if grade.scoreString == "-" || scoreString.hasPrefix("(") && scoreString.hasSuffix(")")  {
            titleLabel.alpha = 0.5
            scoreLabel.alpha = 0.7
        }
        else if (grade as? Grade)?.contributesToAverage == false && grade.score != nil {
            //the grade doesn't contribute to the average (artifically dropped)
            titleLabel.alpha = 0.5
            scoreLabel.alpha = 0.7
            editButton.hidden = false
            scoreLabel.text = "(\(scoreLabel.text!))"
        }
        else {
            titleLabel.alpha = 1.0
            scoreLabel.alpha = 1.5
        }
        
    }
}

let TSSetActivityIndicatorEnabledNotification = "edu.gatech.cal.setActivityIndicatorEnabled"

class BackCell : UITableViewCell {
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "setActivityIndicatorEnabled:", name: TSSetActivityIndicatorEnabledNotification, object: nil)
    }
    
    override func prepareForReuse() {
        if let appDelegate = UIApplication.sharedApplication().delegate as? AppDelegate {
            activityIndicator.alpha = appDelegate.networkActivityCount > 0 ? 1.0 : 0.0
        }
        else {
            activityIndicator.alpha = 0.0
        }
    }
    
    func setActivityIndicatorEnabled(notification: NSNotification) {
        self.activityIndicator.startAnimating()
        
        if let visible = notification.object as? Bool {
            UIView.animateWithDuration(0.3, animations: {
                self.activityIndicator.alpha = visible ? 1.0 : 0.0
            })
        }
    }
    
    @IBAction func backButtonPressed(sender: UIButton) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSBackPressedNotification, object: nil)
    }
    
}

class ToggleCell : UITableViewCell {
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var toggle: UISwitch!
    var handler: ((Bool) -> ())?
    
    func decorateWithText(text: String, initialValue: Bool, handler: (Bool) -> ()) {
        label.text = text
        toggle.on = initialValue
        self.handler = handler
    }
    
    @IBAction func toggleToggled(sender: UISwitch) {
        let on = sender.on
        handler?(on)
    }
    
}

class ButtonCell : UITableViewCell {
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var button: UIButton!
    
    func decorateWithText(text: String, buttonImage: String) {
        label.text = text
        let image = UIImage(named: buttonImage)
        button.setImage(image, forState: .Normal)
        button.setImage(image, forState: .Selected)
    }
    
}

class LogoutSettingsCell : TitleCell {
    
    @IBAction func logoutButtonPressed(sender: UIButton) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSLogoutNotification, object: nil)
    }
    
    @IBAction func settingsButtonPressed(sender: UIButton) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSShowSettingsNotification, object: nil)
    }
    
}

class BalloonPopupCell : UITableViewCell {
    
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var cancelButton: UIImageView!
    
    enum PopupCellAction {
        case Action, Cancel, None
    }
    
    func actionForTouch(location: CGPoint) -> PopupCellAction {
        
        let actionFrame = actionButton.convertRect(actionButton.frame, toView: self)
        let actionHitbot = CGRectMake(actionFrame.origin.x - 40.0, actionFrame.origin.y - 60.0, actionFrame.width + 80.0, actionFrame.height + 80.0)
        if CGRectContainsPoint(actionHitbot, location) {
            return .Action
        }
        
        if location.x < 50.0 {
            return .Cancel
        }
        
        return .None
    }
    
}
