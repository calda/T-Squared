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
        controller.pushDelegate(delegate)
    }
    
}

class TitleCell : UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    func decorate(text: String) {
        titleLabel.text = text
    }
    
}

class TitleWithButtonCell : TitleCell {
    
    @IBOutlet weak var button: UILabel!
    
    func decorate(text: String, buttonText: String) {
        decorate(text)
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
        if let url = NSURL(string: attachment.link) {
            controller.presentDocumentFromURL(url)
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

class BackCell : UITableViewCell {
    
    @IBAction func backButtonPressed(sender: UIButton) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSBackNotification, object: nil)
    }
    
}

class LogoutSettingsCell : TitleCell {
    
    @IBAction func settingsButtonPressed(sender: UIButton) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSLogoutNotification, object: nil)
    }
    
}
