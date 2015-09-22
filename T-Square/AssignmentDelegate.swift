//
//  StackableTableDelegates.swift
//  T-Square
//
//  Created by Cal on 8/30/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import UIKit

class AssignmentDelegate : NSObject, StackableTableDelegate {
    
    //MARK: - Configuring Cells
    
    let controller: ClassesViewController
    let assignment: Assignment
    
    init(assignment: Assignment, controller: ClassesViewController) {
        self.controller = controller
        self.assignment = assignment
        super.init()
    }
    
    
    var cells: [(identifier: String, onDisplay: (UITableViewCell, Assignment) -> ())] = [
        
        (identifier: "back", onDisplay: { cell, _ in cell.hideSeparator() }),
        (identifier: "blank", onDisplay: { cell, _ in cell.hideSeparator() }),
        
        (identifier: "announcementTitle", onDisplay: { tableCell, assignment in
            let cell = tableCell as! TitleCell
            cell.decorate(assignment.name)
            cell.hideSeparator()
        }),
        
        (identifier: "message-white", onDisplay: { tableCell, assignment in
            let cell = tableCell as! TitleCell
            cell.decorate("posted in \(assignment.owningClass.name)")
            cell.hideSeparator()
        }),
        
        (identifier: "message-white", onDisplay: { tableCell, assignment in
            let cell = tableCell as! TitleCell
            
            let dateString = assignment.dueDate?.agoString() ?? assignment.rawDueDateString
            cell.decorate("due \(dateString)")
            cell.hideSeparator()
        }),
        
        (identifier: "blank", onDisplay: { cell, _ in cell.hideSeparator() }),
        
        (identifier: "announcementText", onDisplay: { tableCell, assignment in
            let cell = tableCell as! TitleCell
            let message = assignment.message ?? "Loading message..."
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
            onDisplay(cell, assignment)
            return cell
        }
        if indexPath.section == 1 {
            if indexPath.item == assignment.attachments!.count {
                let cell = tableView.dequeueReusableCellWithIdentifier("blank")!
                cell.hideSeparator()
                return cell
            }
            let attachment = assignment.attachments![indexPath.item]
            let cell = tableView.dequeueReusableCellWithIdentifier("attachment")! as! AttachmentCell
            cell.decorate(attachment.fileName)
            cell.hideSeparator()
            return cell
        }
        else if indexPath.section == 2 {
            if indexPath.item == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("boldTitle")! as! TitleCell
                cell.decorate("Submitted Files")
                return cell
            }
            else if indexPath.item == assignment.submissions!.count + 1 {
                return tableView.dequeueReusableCellWithIdentifier("blank")!
            }
            else {
                let attachment = assignment.submissions![indexPath.item - 1]
                let cell = tableView.dequeueReusableCellWithIdentifier("attachment")! as! AttachmentCell
                cell.decorate(attachment.fileName)
                cell.hideSeparator()
                return cell
            }
        }
        else if indexPath.section == 3 {
            if indexPath.item == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("boldTitle")! as! TitleCell
                cell.decorate("Feedback")
                return cell
            }
            else if indexPath.item == 2 {
                return tableView.dequeueReusableCellWithIdentifier("blank")!
            }
            else {
                let cell = tableView.dequeueReusableCellWithIdentifier("announcementText")! as! TitleCell
                cell.decorate(assignment.feedback!)
                cell.hideSeparator()
                return cell
            }
        }
        else { //if section ==
            if indexPath.item == 0 {
                return tableView.dequeueReusableCellWithIdentifier("blank")!
            }
            let cell = tableView.dequeueReusableCellWithIdentifier("boldTitle") as! TitleCell
            cell.decorate("Submit Assignment")
            return cell
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return cells.count }
        else if section == 1 { return assignment.attachments == nil ? 0 : assignment.attachments!.count + (assignment.submissions != nil ? 1 : 0) }
        else if section == 2 { return assignment.submissions == nil ? 0 : assignment.submissions!.count + 2 }
        else if section == 3 { return assignment.feedback != nil ? 3 : 0 }
        else if section == 4 { return !assignment.completed ? 2 : 0 }
        else { return 0 }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 5
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == 4 && indexPath.item == 0 {
            return 20.0
        }
        
        if indexPath.section == 0 {
            let identifier = cells[indexPath.item].identifier
            if identifier == "blank" { return heightForBlankCellAtIndexPath(indexPath) }
            if identifier == "back" { return 50.0 }
            if identifier == "attachment" { return 50.0 }
            
            let fontSize: CGFloat
            let text: String
            switch(identifier) {
                case "announcementTitle": fontSize = 22.0; text = assignment.name; break;
                case "announcementTitle": fontSize = 17.0; text = "Due \(assignment.dueDate ?? assignment.rawDueDateString)"; break;
                case "announcementText": fontSize = 18.0; text = assignment.message ?? "Loading message..."; break;
                default: fontSize = 19.0; text = "";
            }
            let height = heightForText(text, width: tableView.frame.width - 24.0, font: UIFont.systemFontOfSize(fontSize))
            
            if identifier == "announcementText" {
                return max(100.0, height + 30.0)
            }
            return height
        }
        
        if indexPath.section == 2 && indexPath.item == 0 { return 40.0 }
        if indexPath.section == 1 && indexPath.item == assignment.attachments!.count {
            return heightForBlankCellAtIndexPath(indexPath)
        }
        if indexPath.section == 2 && indexPath.item == assignment.submissions!.count + 1 {
            return heightForBlankCellAtIndexPath(indexPath)
        }
        if indexPath.item == 1 && indexPath.section == 3 {
            let text = assignment.feedback!
            let height = heightForText(text, width: tableView.frame.width - 24.0, font: UIFont.systemFontOfSize(19.0))
            return height * 1.1
        }
        if indexPath.item == 2 && indexPath.section == 3 {
            return heightForBlankCellAtIndexPath(indexPath)
        }
        else { return 50.0 }
    }
    
    func heightForBlankCellAtIndexPath(indexPath: NSIndexPath) -> CGFloat {
        let rowsInSection = tableView(controller.tableView, numberOfRowsInSection: indexPath.section)
        //find out if this is the last section
        if indexPath.item == (rowsInSection - 1) {
            //find out if this is the last section
            let sectionCount = numberOfSectionsInTableView(controller.tableView)
            if indexPath.section == (sectionCount - 1) { return 50.0 }
            //find out if all following sections have no cell
            for section in (indexPath.section + 1) ..< sectionCount {
                let rowsInSection = tableView(controller.tableView, numberOfRowsInSection: section)
                if rowsInSection != 0 { return 15.0 }
            }
            //return 50.0 if this is the definitive last cell in the table
            //this prevents filler cells with 15.0
            return 50.0
        }
        return 15.0
    }
    
    //MARK: - Stackable Table Delegate methods
    
    func loadData() {
        assignment.loadMessage()
    }
    
    func loadCachedData() {
        return
    }
    
    func isFirstLoad() -> Bool {
        return assignment.message == nil
    }
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        return (index.section == 1 && index.item != 0) || (index.section == 4 && index.item == 1 )
    }
    
    func processSelectedCell(index: NSIndexPath) {
        if index.section == 0 {
            if cells[index.item].identifier == "announcementText" {
                if let message = assignment.message {
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
            return
        }
        
        if index.section == 4 && index.item != 0 {
            let link = assignment.link
            controller.openLinkInSafari(link, title: "Assignment")
            delay(0.1) {
                self.controller.loginController.browserViewController.scrollToBottomWhenDoneLoading = true
            }
            return
        }
        
        var attachment: Attachment?
        
        if index.section == 1 {
            attachment = assignment.attachments![index.item]
        }
        if index.section == 2 {
            attachment = assignment.submissions![index.item - 1]
        }
        
        if let attachment = attachment {
            AttachmentCell.presentAttachment(attachment, inController: controller)
        }
    }
    
    func animateSelection(cell: UITableViewCell, indexPath: NSIndexPath, selected: Bool) {
        if indexPath.section == 4 {
            UIView.animateWithDuration(0.3, animations: {
                cell.backgroundColor = UIColor(white: 1.0, alpha: selected ? 0.3 : 0.0)
            })
        }
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: false)
        delay(0.5) {
            NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: true)
        }
    }
    
}