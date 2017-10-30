//
//  SettingsDelegate.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 10/4/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation
import UIKit

let TSDisclaimerText = "Cal is a student at Georgia Tech. He is in no way affiliated with campus officials. This app is an unofficial service provided at user discretion. Saved account information is encrypted, and only leaves the device to authenticate with Georgia Tech's official login service."
let TSLicenseText = "T-Squared is licensed under the GNU General Public License v2.0. Source Code is provided for those interested in validating the security of their credentials. "
let TSEmailText = "Please feel free to send an email with any feedback, issues, or requests. T-Squared can only get better with the help of people like you!"
let TSAvailableWidth = UIScreen.main.bounds.width - 24.0


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
                cell.subjectLabel.text = "Version \(Bundle.applicationVersionNumber) (\(Bundle.applicationBuildNumber))"
            }
        }, onTap: nil),
        
        //author
        (identifier: "subtitle", height: 30.0, onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate("Developed by Cal Stephens")
            }
        }, onTap: { controller in
            controller.openLinkInWebView("http://calstephens.tech", title: "Developer Website")
        }),
        
        //disclaimer
        (identifier: "gradeComment", height: heightForText(TSDisclaimerText, width: TSAvailableWidth - 50.0, font: UIFont.systemFont(ofSize: 15.0)) + 20.0, onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate(TSDisclaimerText)
                cell.titleLabel.alpha = 0.45
            }
        }, onTap: nil),
        
        
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
        (identifier: "gradeComment", height: heightForText(TSEmailText, width: TSAvailableWidth - 50.0, font: UIFont.systemFont(ofSize: 15.0)), onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate(TSEmailText)
                cell.titleLabel.alpha = 0.45
            }
        }, onTap: nil),
        
        //blank
        (identifier: "blank", height: 15.0, onDisplay: nil, onTap: nil),
 
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
            controller.openLinkInWebView("http://calstephens.tech", title: "Developer Website")
        }),
        
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
                controller.openLinkInWebView("https://github.com/calda/T-Square", title: "Source Code")
        }),
        
        //blank
        (identifier: "blank", height: 15.0, onDisplay: nil, onTap: nil),
        
        //license
        (identifier: "boldTitle", height: 30.0, onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate("License")
            }
        }, onTap: { controller in
                controller.openLinkInWebView("http://choosealicense.com/licenses/gpl-2.0/", title: "License")
        }),
        
        //disclaimer
        (identifier: "gradeComment", height: heightForText(TSLicenseText, width: TSAvailableWidth - 50.0, font: UIFont.systemFont(ofSize: 15.0)) + 20.0, onDisplay: { cell in
            if let cell = cell as? TitleCell {
                cell.decorate(TSLicenseText)
                cell.titleLabel.alpha = 0.45
            }
        }, onTap: { controller in
                controller.openLinkInWebView("http://choosealicense.com/licenses/gpl-2.0/", title: "License")
        })
        
    ]
    
    //MARK: - Table View Delegates
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return cells[indexPath.item].height
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let (identifier, _, onDisplay, _) = cells[indexPath.item]
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)!
        onDisplay?(cell)
        cell.hideSeparator()
        return cell
    }
    
    //MARK: - Stackable Table Delegate
    
    func processSelectedCell(_ index: IndexPath) {
        cells[index.item].onTap?(controller)
    }
    
    func canHighlightCell(_ index: IndexPath) -> Bool {
        return cells[index.item].onTap != nil
    }
    
    func animateSelection(_ cell: UITableViewCell, indexPath: IndexPath, selected: Bool) {
        let backgroundColor = UIColor(white: 1.0, alpha: selected ? 0.2 : 0.0)
        UIView.animate(withDuration: 0.3, animations: {
            cell.backgroundColor = backgroundColor
        })
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: TSSetTouchDelegateEnabledNotification), object: false)
        delay(0.5) {
            NotificationCenter.default.post(name: Notification.Name(rawValue: TSSetTouchDelegateEnabledNotification), object: true)
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
