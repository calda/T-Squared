//
//  StackableTableDelegates.swift
//  T-Square
//
//  Created by Cal on 8/30/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import UIKit

class AnnouncementDelegate : NSObject, StackableTableDelegate {
    
    //MARK: - Configuring Cells
    
    let controller: ClassesViewController
    let announcement: Announcement
    var otherAnnouncements: [Announcement] = []
    
    init(announcement: Announcement, controller: ClassesViewController) {
        self.announcement = announcement
        for other in announcement.owningClass.announcements {
            if announcement.name != other.name {
                self.otherAnnouncements.append(other)
            }
        }
        self.controller = controller
        announcement.loadMessage({ _ in
            controller.reloadTable()
            announcement.hasBeenRead()
        })
    }
    
    
    let cells: [(identifier: String, onDisplay: (UITableViewCell, Announcement) -> ())] = [

        (identifier: "back", onDisplay: { cell, _ in cell.hideSeparator() }),
        (identifier: "blank", onDisplay: { cell, _ in cell.hideSeparator() }),
        
        (identifier: "announcementTitle", onDisplay: { tableCell, announcement in
            let cell = tableCell as! TitleCell
            cell.decorate(announcement.name)
            cell.hideSeparator()
        }),
        
        (identifier: "message-white", onDisplay: { tableCell, announcement in
            let cell = tableCell as! TitleCell
            var authorName = announcement.author
            //correct to FIRST LAST instead of LAST, FIRST
            let splits = authorName.componentsSeparatedByString(",")
            if splits.count == 2 {
                authorName = splits[1].cleansed() + " " + splits[0]
                //also trim out middle names???
                let nameParts = authorName.componentsSeparatedByString(" ")
                if nameParts.count == 3 {
                    authorName = nameParts[0] + " " + nameParts[2]
                }
            }
            cell.decorate("posted by \(authorName)")
            cell.hideSeparator()
        }),
        
        (identifier: "message-white", onDisplay: { tableCell, announcement in
            let cell = tableCell as! TitleCell
            if let date = announcement.date {
                let longDateString = NSDateFormatter.localizedStringFromDate(date, dateStyle: .LongStyle, timeStyle: .NoStyle)
                let dateString = longDateString.componentsSeparatedByString(",")[0]
                let timeString = NSDateFormatter.localizedStringFromDate(date, dateStyle: .NoStyle, timeStyle: NSDateFormatterStyle.ShortStyle).lowercaseString
                let combinedString = "\(timeString) on \(dateString)"
                cell.decorate(combinedString)
            }
            else {
                cell.decorate(announcement.rawDateString)
            }
            cell.hideSeparator()
        }),
        
        (identifier: "blank", onDisplay: { cell, _ in cell.hideSeparator() }),
        
        (identifier: "announcementText", onDisplay: { tableCell, announcement in
            let cell = tableCell as! TitleCell
            cell.decorate(announcement.message ?? "Loading message...")
            cell.hideSeparator()
        }),
        
        (identifier: "blank", onDisplay: { cell, _ in cell.hideSeparator() })
    ]
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let (identifier, onDisplay) = cells[indexPath.item]
            let cell = tableView.dequeueReusableCellWithIdentifier(identifier)!
            onDisplay(cell, announcement)
            return cell
        }
        else { //section 1 is other announcements
            if indexPath.item == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("title")! as! TitleCell
                cell.decorate("Other Announcements in \(announcement.owningClass.name)")
                return cell
            }
            else {
                let cell = tableView.dequeueReusableCellWithIdentifier("announcement")! as! AnnouncementCell
                cell.decorate(otherAnnouncements[indexPath.item - 1])
                return cell
            }
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? cells.count : otherAnnouncements.count + 1
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == 0 {
            let identifier = cells[indexPath.item].identifier
            if identifier == "blank" { return 15.0 }
            if identifier == "back" { return 50.0 }
            let fontSize: CGFloat
            let text: String
            switch(identifier) {
                case "announcementTitle": fontSize = 22.0; text = announcement.name; break;
                case "announcementTitle": fontSize = 17.0; text = "posted by \(announcement.author)"; break;
                case "announcementText": fontSize = 18.0; text = announcement.message ?? "Loading message..."; break;
                default: fontSize = 19.0; text = "";
            }
            let height = heightForText(text, width: tableView.frame.width - 24.0, font: UIFont.systemFontOfSize(fontSize))
            
            if identifier == "announcementText" {
                return max(100.0, height)
            }
            return height
        }
        else {
            if indexPath.item == 0 { return 40.0 }
            else { return 60.0 }
        }
    }
    
    //MARK: - Stackable Table Delegate methods
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        return index.section == 1 && index.item != 0
    }
    
    func processSelectedCell(index: NSIndexPath) {
        if index.section == 0 || index.item == 0 { return }
    }
    
    func animateSelection(cell: UITableViewCell, indexPath: NSIndexPath, selected: Bool) {
        return
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: false)
        delay(0.5) {
            NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: true)
        }
    }
    
}