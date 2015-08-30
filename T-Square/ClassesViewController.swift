//
//  ClassesView.swift
//  T-Square
//
//  Created by Cal on 8/27/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import UIKit

class ClassesViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {

    var classes: [Class]?
    var loadingAnnouncements: Bool = true
    var announcements: [Announcement] = []
    var announcementIndexOffset: Int {
        get {
            return (announcements.count == 0 ? 2 : 1)
        }
    }
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var bottomView: UIView!
    @IBOutlet weak var bottomViewHeight: NSLayoutConstraint!
    
    //MARK: - Table View cell arrangement
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return (classes?.count ?? 0) }
        else { return announcements.count + (announcements.count == 0 ? 2 : 1) }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 70.0
        }
        if indexPath.section == 1 {
            return indexPath.item == 0 ? 30.0 : 60.0
        }
        return 50.0
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let index = indexPath.item
        let section = indexPath.section
        
        //classes
        if section == 0 {
            if let classes = classes {
                let displayClass = classes[index]
                let cell = tableView.dequeueReusableCellWithIdentifier("class") as! ClassNameCell
                cell.decorate(displayClass)
                return cell
            }
        }
        
        //announcements
        if section == 1 {
            if index == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("title") as! TitleCell
                cell.decorate("Recent Announcements")
                return cell
            }
            if index == 1 && announcements.count == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("message") as! TitleCell
                cell.decorate(loadingAnnouncements ? "Loading Announcements..." : "No announcements posted")
                return cell
            }
            let announcement = announcements[index - announcementIndexOffset]
            let cell = tableView.dequeueReusableCellWithIdentifier("announcement") as! AnnouncementCell
            cell.decorate(announcement)
            return cell
        }
        
        return tableView.dequeueReusableCellWithIdentifier("class")!
    }
    
    func reloadTable() {
        self.tableView.reloadData()
        updateBottomView()
    }
    
    //MARK: - Handle announcements as they're loaded
    
    func addAnnouncements(newAnnouncements: [Announcement]) {
        for ann in newAnnouncements {
            announcements.append(ann)
            ann.date!.timeIntervalSinceDate(ann.date!)
        }
        
        //resort
        announcements.sortInPlace({ ann1, ann2 in
            if let date1 = ann1.date, let date2 = ann2.date {
                return date1.timeIntervalSinceDate(date2) > 0
            }
            return false
        })
        
        //trim to most recent 5
        if announcements.count > 5 {
            let first = announcements.indices.first!
            let last = announcements.indices.last!
            announcements.removeRange(first.advancedBy(5)...last)
        }
        
        self.reloadTable()
    }
    
    func doneLoadingAnnoucements() {
        loadingAnnouncements = false
        reloadTable()
    }
    
    //MARK: - Customization of the view
    
    override func viewDidAppear(animated: Bool) {
        updateBottomView()
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        updateBottomView()
    }
    
    func updateBottomView() {
        let contentHeight = tableView.contentSize.height
        let scroll = tableView.contentOffset.y
        let height = tableView.frame.height
        
        let viewHeight = max(0, height - (contentHeight - scroll))
        bottomViewHeight.constant = viewHeight
        self.view.layoutIfNeeded()
    }
    
}

//MARK: - Table View Cells

class ClassNameCell : UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var subjectLabel: UILabel!
    
    func decorate(displayClass: Class) {
        nameLabel.text = displayClass.name
        subjectLabel.text = displayClass.subjectName ?? ""
    }
    
}

class AnnouncementCell : UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    static var originalDescriptionText: NSAttributedString?
    
    func decorate(announcement: Announcement) {
        if AnnouncementCell.originalDescriptionText == nil {
            AnnouncementCell.originalDescriptionText = descriptionLabel.attributedText
        }
        
        titleLabel.text = announcement.name
        
        //decorate label with time
        let timeAgo = announcement.date?.agoString() ?? announcement.rawDateString
        let className = announcement.owningClass.name
        let attributed = AnnouncementCell.originalDescriptionText?.mutableCopy() as? NSMutableAttributedString
            ?? descriptionLabel.attributedText!.mutableCopy() as! NSMutableAttributedString
        attributed.replaceCharactersInRange(NSMakeRange(18, 8), withString: className)
        attributed.replaceCharactersInRange(NSMakeRange(0, 14), withString: timeAgo)
        descriptionLabel.attributedText = attributed
    }
    
}

class TitleCell : UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    func decorate(text: String) {
        titleLabel.text = text
    }
    
}

