//
//  AnnouncementDelegate.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 8/30/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
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
        super.init()
        
        if announcement.message == nil {
            controller.setActivityIndicatorVisible(true)
        }
        
        announcement.loadMessage({ _ in
            
            if let attachments = announcement.attachments {
                
                self.cells.removeLast()
                
                for attachment in attachments {
                    self.cells.insert((identifier: "attachment", onDisplay: { tableCell, announcement in
                        let cell = tableCell as! AttachmentCell
                        cell.decorate(attachment.fileName)
                        cell.hideSeparator()
                    }), atIndex: self.cells.count)
                }
                
            }
            
            controller.reloadTable()
            announcement.markRead()
            controller.setActivityIndicatorVisible(false)
            
            //open the announcement in a web view if the text wasn't parsed properly
            if announcement.message?.isEmpty == true || announcement.message?.isWhitespace() == true {
                controller.openLinkInWebView(announcement.link, title: "Announcement")
            }
            
        })
    }
    
    
    var cells: [(identifier: String, onDisplay: (UITableViewCell, Announcement) -> ())] = [

        (identifier: "back", onDisplay: { cell, _ in cell.hideSeparator() }),
        (identifier: "blank", onDisplay: { cell, _ in cell.hideSeparator() }),
        
        (identifier: "announcementTitle", onDisplay: { tableCell, announcement in
            let cell = tableCell as! TitleCell
            cell.decorate(announcement.name)
            cell.hideSeparator()
        }),
        
        (identifier: "message-white", onDisplay: { tableCell, announcement in
            let cell = tableCell as! TitleCell
            cell.decorate("posted in \(announcement.owningClass.name)")
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
            
            let dateString = announcement.date?.agoString() ?? announcement.rawDateString
            cell.decorate("\(dateString) by \(authorName)")
            cell.hideSeparator()
        }),
        
        (identifier: "blank2", onDisplay: { cell, _ in cell.hideSeparator() }),
        
        (identifier: "message-white-button", onDisplay: { tableCell, announcement in
            let cell = tableCell as! TitleCell
            cell.decorate("View on T-Square")
            cell.hideSeparator()
        }),
        
        (identifier: "blank", onDisplay: { cell, _ in cell.hideSeparator() }),
        
        (identifier: "announcementText", onDisplay: { tableCell, announcement in
            let cell = tableCell as! TitleCell
            let message = announcement.message ?? "Loading message..."
            let attributed = attributedStringWithHighlightedLinks(message, linkColor: UIColor(hue: 0.58, saturation: 0.84, brightness: 0.53, alpha: 1.0))
            
            cell.titleLabel.attributedText = attributed
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
            if identifier == "blank2" { return 8.0 }
            if identifier == "back" { return 50.0 }
            if identifier == "attachment" { return 50.0 }
            if identifier == "message-white-button" { return 30.0 }
            
            let fontSize: CGFloat
            let text: String
            switch(identifier) {
                case "announcementTitle": fontSize = 22.5; text = announcement.name; break;
                case "announcementText": fontSize = 18.5; text = announcement.message ?? "Loading message..."; break;
                default: fontSize = 19.0; text = "";
            }
            
            let font: UIFont
            if #available(iOS 8.2, *) {
                font = UIFont.systemFontOfSize(fontSize, weight: UIFontWeightThin)
            } else {
                font = UIFont.systemFontOfSize(fontSize)
            }
            
            let height = heightForText(text, width: tableView.frame.width - 30.0, font: font)
            
            if identifier == "announcementText" {
                if text.isWhitespace() || text.isEmpty {
                    return 0.0
                }
                return max(100.0, height + 30.0)
            }
            return height
        }
        else {
            if indexPath.item == 0 { return 40.0 }
            else { return 60.0 }
        }
    }
    
    //MARK: - Stackable Table Delegate methods
    
    func loadData() {
        return
    }
    
    func loadCachedData() {
        return
    }
    
    func isFirstLoad() -> Bool {
        return false
    }
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        if index.section == 1 && index.item != 0 { return true }
        
        if index.section == 0 {
            let identifier = cells[index.item].identifier
            if identifier == "attachment" || identifier == "message-white-button" {
                return true
            }
        }
        
        return false
    }
    
    func processSelectedCell(index: NSIndexPath) {
        if index.section == 0 {
            if cells[index.item].identifier == "attachment" {
                let attachment = announcement.attachments![self.cells.count - 1 - index.item]
                AttachmentCell.presentAttachment(attachment, inController: self.controller)
            }
            if cells[index.item].identifier == "announcementText" {
                if let message = announcement.message {
                    let linksAndRanges = linksInText(message)
                    //build array with only links
                    if linksAndRanges.count != 0 {
                        var links: [String] = []
                        for (link, _) in linksAndRanges {
                            links.append(link)
                        }
                        controller.openFromLinks(links)
                    }
                }
            }
            if cells[index.item].identifier == "message-white-button" {
                //Open on T-Square button
                controller.openLinkInWebView(announcement.link, title: "Announcement")
            }
        }
        else if index.section == 1 && index.item != 0 {
            let otherAnnouncement = otherAnnouncements[index.item - 1]
            AnnouncementCell.presentAnnouncement(otherAnnouncement, inController: self.controller)
        }
    }
    
    func animateSelection(cell: UITableViewCell, indexPath: NSIndexPath, selected: Bool) {
        
        //don't highlight "Other Announcements in..." cell
        if let cell = self.controller.tableView.cellForRowAtIndexPath(indexPath) as? TitleCell where cell.titleLabel.text?.hasPrefix("Other Announcements") == true {
            return //this is a gnarly fix that doesn't want to resolve itself any other way
        }
        
        let normalColor: UIColor
        let touchColor: UIColor
        
        if indexPath.section == 1 { //other announcements
            normalColor = UIColor(red: 0.43, green: 0.69, blue: 1.0, alpha: indexPath.item == 0 ? 0.0 : 0.4)
            touchColor = UIColor(hue: 0.5833333333, saturation: 1.0, brightness: 1.0, alpha: 0.1)
        } else {
            normalColor = UIColor.clearColor()
            touchColor = UIColor(white: 1.0, alpha: 0.3)
        }
        
        let newBackground = selected ? touchColor : normalColor
        UIView.animateWithDuration(0.3, animations: {
            cell.backgroundColor = newBackground
        })
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: false)
        delay(0.5) {
            NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: true)
        }
    }
    
}
