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
    
    init(announcement: Announcement, controller: ClassesViewController) {
        self.announcement = announcement
        self.controller = controller
        announcement.loadMessage({ _ in
            controller.reloadTable()
        })
    }
    
    let cells: [(identifier: String, onDisplay: (UITableViewCell, Announcement) -> ())] = [

        (identifier: "announcementTitle", onDisplay: { tableCell, announcement in
            let cell = tableCell as! TitleCell
            cell.decorate(announcement.name)
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
        }),
        
        (identifier: "announcementText", onDisplay: { tableCell, announcement in
            let cell = tableCell as! TitleCell
            cell.decorate(announcement.message ?? "Loading message...")
        }),
    ]
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let (identifier, onDisplay) = cells[indexPath.item]
        let cell = tableView.dequeueReusableCellWithIdentifier(identifier)! as! TitleCell
        onDisplay(cell, announcement)
        return cell
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let identifier = cells[indexPath.item].identifier
        let fontSize: CGFloat
        let text: String
        switch(identifier) {
            case "announcementTitle": fontSize = 22.0; text = announcement.name; break;
            case "announcementTitle": fontSize = 17.0; text = "posted by \(announcement.author)"; break;
            case "announcementText": fontSize = 16.0; text = announcement.message ?? "Loading message..."; break;
            default: fontSize = 19.0; text = "";
        }
        let height = heightForText(text, width: tableView.frame.width - 24.0, font: UIFont.systemFontOfSize(fontSize)) + 10
        
        if identifier == "announcementText" {
            return max(50.0, height + 20)
        }
        return height
    }
    
    //MARK: - Stackable Table Delegate methods
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        return false
    }
    
    func processSelectedCell(index: NSIndexPath) {
        return
    }
    
    func animateSelection(cell: UITableViewCell, indexPath: NSIndexPath, selected: Bool) {
        return
    }
    
}