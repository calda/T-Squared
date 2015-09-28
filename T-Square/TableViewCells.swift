//
//  TableViewCells.swift
//  T-Square
//
//  Created by Cal on 9/1/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import UIKit

class ClassNameCell : UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var subjectLabel: UILabel!
    
    func decorate(displayClass: Class) {
        nameLabel.text = displayClass.name
        subjectLabel.text = displayClass.subjectName ?? ""
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
    
    func decorate(text: String, buttonText: String) {
        titleLabel.text = text
        button.text = buttonText
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
        if let link = attachment.link, url = NSURL(string: link) {
            controller.presentDocumentFromURL(url)
        }
        
        else if let rawText = attachment.rawText {
            controller.openTextInSafari(rawText, title: attachment.fileName)
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
    
    func decorateForGradeGroup(group: GradeGroup) {
        titleLabel.text = group.name
        scoreLabel.text = group.scoreString
        
        if let weight = group.weight {
            weightLabel.text = "Weight: \(Int(weight * 100))%"
        }
        else {
            weightLabel.text = "Unspecified Weight"
        }
    }
    
}

class GradeCell : UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    
    func decorateForScore(grade: Scored) {
        titleLabel.text = grade.name
        scoreLabel.text = grade.scoreString
    }
}

class BackCell : UITableViewCell {
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "setActivityIndicatorEnabled:", name: TSSetActivityIndicatorVisibleNotification, object: nil)
    }
    
    func setActivityIndicatorEnabled(notification: NSNotification) {
        activityIndicator.startAnimating()
        
        if let visible = notification.object as? Bool {
            UIView.animateWithDuration(0.3, animations: {
                self.activityIndicator.alpha = visible ? 1.0 : 0.0
            })
        }
    }
    
    @IBAction func backButtonPressed(sender: UIButton) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSBackNotification, object: nil)
    }
    
}

class LogoutSettingsCell : TitleCell {
    
    @IBAction func settingsButtonPressed(sender: UIButton) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSLogoutNotification, object: nil)
    }
    
}
