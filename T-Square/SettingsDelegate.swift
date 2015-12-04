//
//  SettingsDelegate.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 10/4/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation
import UIKit

let TSDisclaimerText = "Cal is a freshman at Georgia Tech. He is in no way affiliated with campus officials. This app is an unofficial service provided at user discretion. Saved account information is encrypted, and only leaves the device to authenticate with Georgia Tech's official login service."
let TSLicenseText = "T-Squared is licensed under the GNU General Public License v2.0. Source Code is provided for those interested in validating the security of their credentials. "
let TSEmailText = "Please feel free to send an email with any feeback, issues, or requests! T-Sqaured can only get better with the help of people like you!"
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
                cell.titleLabel.alpha = 0.45
            }
        }, onTap: nil),
        
        //website title
        (identifier: "boldTitle", height: 30.0, onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate("Website")
            }
        }, onTap: nil),
        
        //website link
        (identifier: "subtitle", height: 30.0, onDisplay: { cell in
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
        (identifier: "subtitle", height: 35.0, onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate("cal@calstephens.tech")
            }
        }, onTap: { controller in
            controller.openContactEmail()
        }),
        
        //disclaimer
        (identifier: "gradeComment", height: heightForText(TSEmailText, width: TSAvailableWidth - 50.0, font: UIFont.systemFontOfSize(15.0)), onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate(TSEmailText)
                cell.titleLabel.alpha = 0.45
            }
        }, onTap: nil),
        
        //blank
        (identifier: "blank", height: 15.0, onDisplay: nil, onTap: nil),
        
        //source code title
        (identifier: "boldTitle", height: 30.0, onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate("Source Code")
            }
            }, onTap: nil),
        
        //source code link
        (identifier: "subtitle", height: 30.0, onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate("GitHub")
            }
        }, onTap: { controller in
                controller.openLinkInSafari("https://github.com/calda/T-Square", title: "Source Code")
        }),
        
        //blank
        (identifier: "blank", height: 15.0, onDisplay: nil, onTap: nil),
        
        //license
        (identifier: "boldTitle", height: 30.0, onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate("License")
            }
        }, onTap: { controller in
                controller.openLinkInSafari("http://choosealicense.com/licenses/gpl-2.0/", title: "License")
        }),
        
        //disclaimer
        (identifier: "gradeComment", height: heightForText(TSLicenseText, width: TSAvailableWidth - 50.0, font: UIFont.systemFontOfSize(15.0)) + 20.0, onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate(TSLicenseText)
                cell.titleLabel.alpha = 0.45
            }
        }, onTap: { controller in
                controller.openLinkInSafari("http://choosealicense.com/licenses/gpl-2.0/", title: "License")
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
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: false)
        delay(0.5) {
            NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: true)
        }
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