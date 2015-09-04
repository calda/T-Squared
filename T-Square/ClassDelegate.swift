//
//  ClassDelegate.swift
//  T-Square
//
//  Created by Cal on 9/3/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import UIKit

class ClassDelegate : NSObject, StackableTableDelegate {
    
    //MARK: - Table View Delegate methods
    
    let controller: ClassesViewController
    let displayClass: Class
    
    init(controller: ClassesViewController, displayClass: Class) {
        self.controller = controller
        self.displayClass = displayClass
    }
    
    static let hideSeparator: (UITableViewCell, Class) -> () = { cell, _ in
        cell.hideSeparator()
    }
    
    static func titleDisplayWithText(text: String, hideSeparator: Bool = false) -> (UITableViewCell, Class) -> () {
        return { cell, displayClass in
            if let cell = cell as? TitleCell {
                cell.decorate(text)
            }
            if hideSeparator {
                cell.hideSeparator()
            }
        }
    }
    
    var cells: [(identifier: String, onDisplay: (UITableViewCell, Class) -> () )] = [
    
        (identifier: "back", onDisplay: hideSeparator),
        (identifier: "classTitle", onDisplay: { cell, displayClass in
            if let cell = cell as? ClassNameCell {
                cell.decorate(displayClass)
                cell.hideSeparator()
            }
        }),
        
        (identifier: "blank", onDisplay: hideSeparator),
        (identifier: "standardTitle", onDisplay: ClassDelegate.titleDisplayWithText("Assignments")),
        (identifier: "standardTitle", onDisplay: ClassDelegate.titleDisplayWithText("Resources")),
        (identifier: "standardTitle", onDisplay: ClassDelegate.titleDisplayWithText("Gradebook")),
        (identifier: "standardTitle", onDisplay: ClassDelegate.titleDisplayWithText("Syllabus", hideSeparator: true)),
        (identifier: "blank", onDisplay: hideSeparator)
        
    ]
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return cells.count
        }
        else if section == 1 {
            return max(2, displayClass.announcements.count + 1)
        }
        else { return 0 }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let (identifier, onDisplay) = cells[indexPath.item]
            let cell = tableView.dequeueReusableCellWithIdentifier(identifier)!
            onDisplay(cell, displayClass)
            return cell
        }
        
        if indexPath.section == 1 {
            if indexPath.item == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("title") as! TitleCell
                cell.decorate("Announcements")
                return cell
            }
            
            if indexPath.item == 1 && displayClass.announcements.count == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("message") as! TitleCell
                cell.decorate(controller.loadingAnnouncements ? "Loading Announcements..." : "Nothing here yet.")
                return cell
            }
            
            let index = indexPath.item - 1
            let cell = tableView.dequeueReusableCellWithIdentifier("announcement") as! AnnouncementCell
            cell.decorate(displayClass.announcements[index])
            return cell
        }
        
        return tableView.dequeueReusableCellWithIdentifier("announcementTitle")!
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == 0 {
            let identifier = cells[indexPath.item].identifier
            if identifier == "blank" { return 15.0 }
            if identifier == "classTitle" { return 80.0 }
            if identifier == "announcementTitle" { return 60.0 }
        }
        if indexPath.section == 1 {
            if indexPath.item == 0 { return 40.0 }
            else { return 60.0 }
        }
        return 50.0
    }
    
    //MARK: - Stackable Delegate methods
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        return index.section == 0
               ? index.item >= 3
               : index.item != 0
    }
    
    func processSelectedCell(index: NSIndexPath) {
        if index.section == 1 {
            if index.item == 0 { return }
            if index.item == 1 && displayClass.announcements.count == 0 { return }
            let announcement = displayClass.announcements[index.item - 1]
            controller.pushDelegate(AnnouncementDelegate(announcement: announcement, controller: controller))
        }
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: false)
        delay(0.5) {
            NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: true)
        }
    }
    
    func animateSelection(cell: UITableViewCell, indexPath: NSIndexPath, selected: Bool) {
        let background: UIColor
        if indexPath.section == 0 {
            background = UIColor(white: 1.0, alpha: selected ? 0.3 : 0.0)
        }
        else { //if section == 1
            if indexPath.item == 0 { return }
            if indexPath.item == 1 && displayClass.announcements.count == 0 { return }
            if selected {
                background = UIColor(hue: 0.5833333333, saturation: 1.0, brightness: 1.0, alpha: 0.1)
            }
            else {
                background = UIColor(red: 0.43, green: 0.69, blue: 1.0, alpha: 0.4)
            }
        }
        
        UIView.animateWithDuration(0.3, animations: {
            cell.backgroundColor = background
        })
    }
    
}