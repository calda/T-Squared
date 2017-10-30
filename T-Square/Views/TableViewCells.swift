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
    
    func decorate(_ displayClass: Class) {
        nameLabel.text = displayClass.name
        subjectLabel.text = displayClass.subjectName ?? ""
        displayClass.displayCell = self
    }
    
}

class ClassNameCellWithIcon : ClassNameCell {
    
    @IBOutlet weak var icon: UIImageView!
    
    override func decorate(_ displayClass: Class) {
        super.decorate(displayClass)
        self.icon.image = UIImage(named: displayClass.subjectIcon)?.withRenderingMode(.alwaysTemplate)
        self.icon.tintColor = UIColor.black
    }
    
}

class ClassNameCellWithSwitch : ClassNameCellWithIcon {
    
    @IBOutlet weak var toggleSwitch: UISwitch!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    var displayClass: Class?
    var preferencesLink: String?
    var controller: ClassesViewController?
    
    func decorate(_ displayClass: Class, preferencesLink: String?, controller: ClassesViewController) {
        self.displayClass = displayClass
        self.preferencesLink = preferencesLink
        self.controller = controller
        
        super.decorate(displayClass)
        self.toggleSwitch.isOn = displayClass.isActive
        
        //if there is a toggle in the queue
        if let index = ClassNameCellWithSwitch.activeToggleQueue.index(where: { return $0.displayClass == displayClass }) {
            let (_, newStatus, _, _) = ClassNameCellWithSwitch.activeToggleQueue[index]
            self.toggleSwitch.isOn = newStatus
            self.toggleSwitch.alpha = 0.0
            self.activityIndicator.alpha = 1.0
            self.activityIndicator.startAnimating()
        }
        
        self.toggleSwitch.isHidden = preferencesLink == nil
    }
    
    @IBAction func switchToggled(_ sender: UISwitch) {
        if let preferencesLink = preferencesLink,
           let displayClass = displayClass,
           let controller = controller {
            
            let newStatus = sender.isOn
            
            //animate indicator visible
            self.activityIndicator.startAnimating()
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
                self.activityIndicator.alpha = 1.0
                self.toggleSwitch.alpha = 0.0
            }, completion: nil)
            
            ClassNameCellWithSwitch.activeToggleQueue.append((displayClass: displayClass, newStatus: newStatus, activityIndicator: activityIndicator, toggleSwitch: toggleSwitch))
            if ClassNameCellWithSwitch.activeToggleQueue.count == 1 {
                ClassNameCellWithSwitch.performActiveToggle(displayClass, newStatus: newStatus, preferencesLink: preferencesLink, controller: controller, activityIndicator: activityIndicator, toggleSwitch: toggleSwitch)
            }
            
            displayClass.isActive = newStatus
            
        } else {
            sender.isOn = !sender.isOn
        }
        
    }
    
    static var activeToggleQueue: [(displayClass: Class, newStatus: Bool, activityIndicator: UIActivityIndicatorView?, toggleSwitch: UISwitch?)] = []
    
    static func performActiveToggle(_ displayClass: Class, newStatus: Bool, preferencesLink: String, controller: ClassesViewController,
        activityIndicator: UIActivityIndicatorView?, toggleSwitch: UISwitch?) {
            
        //make network call
        NotificationCenter.default.post(name: Notification.Name(rawValue: TSPerformingNetworkActivityNotification), object: true)
        TSNetworkQueue.async {
            
            HttpClient.markClassActive(displayClass, active: newStatus, atPreferencesLink: preferencesLink)
            
            sync {
                NotificationCenter.default.post(name: Notification.Name(rawValue: TSPerformingNetworkActivityNotification), object: false)
                //animate switch visible
                UIView.animate(withDuration: 0.8, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
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
                    if let index = controller.classes?.index(of: displayClass) {
                        controller.classes?.remove(at: index)
                    }
                    if let index = TSAuthenticatedReader.classes?.index(of: displayClass) {
                        TSAuthenticatedReader.classes?.remove(at: index)
                    }
                }
                
                //reload if the user already went back to the Classes View Controller
                if controller.tableView.delegate is ClassesViewController {
                    controller.reloadTable()
                }
                
                //done, pull from queue and continue with next
                if let index = activeToggleQueue.index(where: { return $0.displayClass == displayClass }) {
                    activeToggleQueue.remove(at: index)
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
    
    func decorate(_ announcement: Announcement) {
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
        attributed.replaceCharacters(in: NSMakeRange(18, 8), with: className)
        attributed.replaceCharacters(in: NSMakeRange(0, 14), with: timeAgo)
        descriptionLabel.attributedText = attributed
    }
    
    static func presentAnnouncement(_ announcement: Announcement, inController controller: ClassesViewController) {
        let delegate = AnnouncementDelegate(announcement: announcement, controller: controller)
        delegate.loadDataAndPushInController(controller)
    }
    
}

class TitleCell : UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    func decorate(_ text: String) {
        titleLabel.text = text
    }
    
}

class TitleWithButtonCell : BackCell {
    
    
    @IBOutlet weak var button: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    
    func decorate(_ text: String, buttonText: String, activityIndicatorHidden: Bool) {
        titleLabel.text = text
        button.text = buttonText
        activityIndicator.isHidden = activityIndicatorHidden
    }
    
}

class AttachmentCell : TitleCell {
    
    @IBOutlet weak var background: UIView!
    
    override func decorate(_ text: String) {
        super.decorate(text)
        background.layer.cornerRadius = 5.0
        background.layer.masksToBounds = true
    }
    
    static func presentAttachment(_ attachment: Attachment, inController controller: ClassesViewController) {
        if let link = attachment.link, let url = URL(string: link) {
            controller.presentDocumentFromURL(url)
        }
        
        else if let rawText = attachment.rawText {
            controller.openTextInWebView(rawText, title: attachment.fileName)
        }
    }
    
    static func presentResource(_ resource: Resource, inController controller: ClassesViewController) {
        if let url = URL(string: resource.link) {
            controller.presentDocumentFromURL(url)
        }
    }
    
}

class AssignmentCell : UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dueLabel: UILabel!
    
    func decorate(_ assignment: Assignment) {
        titleLabel.text = assignment.name
        
        dueLabel.textColor = UIColor.black
        dueLabel.alpha = 0.5
        
        if assignment.status == .completed {
            dueLabel.text = "✔︎ Completed"
            dueLabel.textColor = UIColor(red: 0.0, green: 0.3, blue: 0.0, alpha: 1.0)
            return
        }
        
        if assignment.status == .returned {
            dueLabel.text = "✔︎ Returned"
            dueLabel.textColor = UIColor(red: 0.0, green: 0.3, blue: 0.0, alpha: 1.0)
            return
        }
        
        if let date = assignment.dueDate {
            dueLabel.text = "Due \(date.agoString())"
            if (dueLabel.text!.contains("hour") || dueLabel.text!.contains("minute")) || date.timeIntervalSinceNow < 0 {
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
    
    func decorateForGradeGroup(_ group: GradeGroup, inClass displayClass: Class) {
        titleLabel.text = group.name
        scoreLabel.text = group.scoreString
        weightLabel.text = nil
        
        if displayClass.grades?.ignoreSubgroupScores == true {
            scoreLabel.text = ""
        } else if group.weight == nil || group.weight == 0.0 {
            scoreLabel.text = ""
            weightLabel.text = "Excluded from average (not weighted, tap to edit)"
        }
        
        if let weight = group.weight, weight != 0.0 {
            weightLabel.text = "Weight: \(Int(weight))%"
        }
        
        if weightLabel.text != nil {
            weightLabel.alpha = 0.5
            titleLabelPosition.constant = -10.0
            titleLabel.baselineAdjustment = .alignBaselines
        }
        else {
            weightLabel.alpha = 0.0
            titleLabelPosition.constant = 0
            titleLabel.baselineAdjustment = .alignCenters
        }
        
        editButton.isHidden = !group.isArtificial
        if !editButton.isHidden {
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
    
    func decorateForScore(_ grade: Scored, inClass displayClass: Class) {
        let name = grade.name.cleansed()
        let scoreString = grade.scoreString
        
        titleLabel.text = name
        scoreLabel.text = scoreString
        editButton.alpha = 0.0
        
        editButton.isHidden = !grade.isArtificial
        editButton.alpha = displayClass.grades?.shouldAppearAsEdited == true ? 1.0 : 0.3
        
        if grade.scoreString == "-" || scoreString.hasPrefix("(") && scoreString.hasSuffix(")")  {
            titleLabel.alpha = 0.5
            scoreLabel.alpha = 0.7
        }
        else if (grade as? Grade)?.contributesToAverage == false && grade.score != nil {
            //the grade doesn't contribute to the average (artifically dropped)
            titleLabel.alpha = 0.5
            scoreLabel.alpha = 0.7
            editButton.isHidden = false
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
        NotificationCenter.default.addObserver(self, selector: #selector(BackCell.setActivityIndicatorEnabled(_:)), name: NSNotification.Name(rawValue: TSSetActivityIndicatorEnabledNotification), object: nil)
    }
    
    override func prepareForReuse() {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            activityIndicator.alpha = appDelegate.networkActivityCount > 0 ? 1.0 : 0.0
        }
        else {
            activityIndicator.alpha = 0.0
        }
    }
    
    func setActivityIndicatorEnabled(_ notification: Notification) {
        self.activityIndicator.startAnimating()
        
        //notification supports Bool or Int
        let indicatorVisible: Bool
        
        if let notificationBool = notification.object as? Bool {
            indicatorVisible = notificationBool
        } else if let notificationInt = notification.object as? Int {
            indicatorVisible = (notificationInt == 1 ? true : false)
        } else {
            return
        }
        
        UIView.animate(withDuration: 0.3, animations: {
            self.activityIndicator.alpha = indicatorVisible ? 1.0 : 0.0
        })
    }
    
    @IBAction func backButtonPressed(_ sender: UIButton) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: TSBackPressedNotification), object: nil)
    }
    
}

class ToggleCell : UITableViewCell {
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var toggle: UISwitch!
    var handler: ((Bool) -> ())?
    
    func decorateWithText(_ text: String, initialValue: Bool, handler: @escaping (Bool) -> ()) {
        label.text = text
        toggle.isOn = initialValue
        self.handler = handler
    }
    
    @IBAction func toggleToggled(_ sender: UISwitch) {
        let on = sender.isOn
        handler?(on)
    }
    
}

class ButtonCell : UITableViewCell {
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var button: UIButton!
    
    func decorateWithText(_ text: String, buttonImage: String) {
        label.text = text
        let image = UIImage(named: buttonImage)
        button.setImage(image, for: UIControlState())
        button.setImage(image, for: .selected)
    }
    
}

class LogoutSettingsCell : TitleCell {
    
    @IBAction func logoutButtonPressed(_ sender: UIButton) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: TSLogoutNotification), object: nil)
    }
    
    @IBAction func settingsButtonPressed(_ sender: UIButton) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: TSShowSettingsNotification), object: nil)
    }
    
}

class BalloonPopupCell : UITableViewCell {
    
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var cancelButton: UIImageView!
    
    enum PopupCellAction {
        case action, cancel, none
    }
    
    func decorateView() {
        if self.layer.shadowPath != nil { return }
        
        let shadowRect = CGRect(x: 0, y: 10, width: self.bounds.width, height: self.bounds.height - 15)
        let shadowPath = UIBezierPath(rect: shadowRect)
        self.layer.masksToBounds = false
        self.clipsToBounds = false
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        self.layer.shadowOpacity = 0.08
        self.layer.shadowPath = shadowPath.cgPath
    }
    
    func actionForTouch(_ location: CGPoint) -> PopupCellAction {
        
        let actionFrame = actionButton.convert(actionButton.frame, to: self)
        let actionHitbot = CGRect(x: actionFrame.origin.x - 40.0, y: actionFrame.origin.y - 60.0, width: actionFrame.width + 80.0, height: actionFrame.height + 80.0)
        if actionHitbot.contains(location) {
            return .action
        }
        
        if location.x < 50.0 {
            return .cancel
        }
        
        return .none
    }
    
}
