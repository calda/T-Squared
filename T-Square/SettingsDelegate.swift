//
//  SettingsDelegate.swift
//  T-Square
//
//  Created by Cal on 10/4/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import UIKit

let TSDisclaimerText = "Cal is a freshman at Georgia Tech. He is in no way affiliated with campus officials. This app is an unofficial service provided at user discretion."
let TSAvailableWidth = UIScreen.mainScreen().bounds.width - 24.0


class SettingsDelegate : NSObject, StackableTableDelegate {
    
    let controller: ClassesViewController
    
    init(controller: ClassesViewController) {
        self.controller = controller
    }
    
    //MARK: - Layout for cells
    
    //strings
    var cells: [(identifier: String, height: CGFloat, onDisplay: ((UITableViewCell) -> ())?, onTap: ((ClassesViewController) -> ())?)] = [
    
        //back
        (identifier: "back", height: 50.0, onDisplay: nil, onTap: nil),
        
        //title
        (identifier: "classTitle", height: 80.0, onDisplay: { cell in
            if let cell = cell as? ClassNameCell {
                cell.nameLabel.text = "T-Squared"
                cell.subjectLabel.text = "Version \(NSBundle.applicationVersionNumber) (\(NSBundle.applicationBuildNumber))"
            }
        }, onTap: nil),
        
        //author
        (identifier: "subtitle", height: 30.0, onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate("Developed by Cal Stephens")
            }
        }, onTap: { controller in
            controller.openLinkInSafari("http://calstephens.tech", title: "Developer Website")
        }),
        
        //disclaimer
        (identifier: "gradeComment", height: heightForText(TSDisclaimerText, width: TSAvailableWidth - 50.0, font: UIFont.systemFontOfSize(15.0)) + 20.0, onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate(TSDisclaimerText)
                cell.titleLabel.alpha = 0.35
            }
        }, onTap: { controller in
            controller.openLinkInSafari("http://calstephens.tech", title: "Developer Website")
        }),
        
        //website title
        (identifier: "boldTitle", height: 30.0, onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate("Website")
            }
        }, onTap: nil),
        
        //website link
        (identifier: "subtitle", height: 40.0, onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate("http://calstephens.tech")
            }
        }, onTap: { controller in
            controller.openLinkInSafari("http://calstephens.tech", title: "Developer Website")
        }),
        
        //blank
        (identifier: "blank", height: 15.0, onDisplay: nil, onTap: nil),

        //email title
        (identifier: "boldTitle", height: 30.0, onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate("Contact")
            }
        }, onTap: nil),
        
        //email link
        (identifier: "subtitle", height: 40.0, onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate("cal@calstephens.tech")
            }
        }, onTap: { controller in
            controller.openContactEmail()
        })
        
    ]
    
    //MARK: - Table View Delegates
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return cells[indexPath.item].height
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let (identifier, _, onDisplay, _) = cells[indexPath.item]
        let cell = tableView.dequeueReusableCellWithIdentifier(identifier)!
        onDisplay?(cell)
        cell.hideSeparator()
        return cell
    }
    
    //MARK: - Stackable Table Delegate
    
    func processSelectedCell(index: NSIndexPath) {
        cells[index.item].onTap?(controller)
    }
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        return cells[index.item].onTap != nil
    }
    
    func animateSelection(cell: UITableViewCell, indexPath: NSIndexPath, selected: Bool) {
        let backgroundColor = UIColor(white: 1.0, alpha: selected ? 0.2 : 0.0)
        UIView.animateWithDuration(0.3, animations: {
            cell.backgroundColor = backgroundColor
        })
    }
    
    func loadCachedData() {
        return
    }
    
    func loadData() {
        return
    }
    
    func isFirstLoad() -> Bool {
        return false
    }
    
}