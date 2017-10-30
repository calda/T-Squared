//
//  AllClassesDelegate.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 9/12/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation
import UIKit

class AllClassesDelegate : NSObject, StackableTableDelegate {
    
    let controller: ClassesViewController
    var allClasses: [Class] = []
    var preferencesLink: String?
    
    init(controller: ClassesViewController) {
        self.controller = controller
    }
    
    //MARK: - Table View Delegate
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (allClasses.count == 0 ? 1 : allClasses.count) + 3
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.item == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "back")!
            cell.hideSeparator()
            return cell
        }
        if indexPath.item == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "classTitle")! as! ClassNameCell
            cell.nameLabel.text = "All Classes"
            cell.subjectLabel.text = "Active and Hidden"
            cell.hideSeparator()
            return cell
        }
        if indexPath.item == 2 {
            return tableView.dequeueReusableCell(withIdentifier: "blank")!
        }
        if indexPath.item == 3 && allClasses.count == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "subtitle")! as! TitleCell
            cell.decorate("You aren't in any classes yet.")
            return cell
        }
        
        let displayClass = allClasses[indexPath.item - 3]
        let cell = tableView.dequeueReusableCell(withIdentifier: "classWithSwitch") as! ClassNameCellWithSwitch
        cell.decorate(displayClass, preferencesLink: self.preferencesLink, controller: self.controller)
        return cell
    }
    
    @objc func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.item == 0 { return 50.0 }
        if indexPath.item == 2 { return 20.0 }
        return 70.0
    }
    
    //MARK: - Stackable Table Delegate Methods
    
    func loadData() {
        let (classes, preferencesLink) = TSAuthenticatedReader.getAllClasses()
        self.preferencesLink = preferencesLink
        
        if classes.count == self.allClasses.count { //there was nothing new loaded, don't override
            return
        }
        
        self.allClasses = classes
    }
    
    func loadCachedData() {
        (self.allClasses, self.preferencesLink) = TSAuthenticatedReader.allClassesCached ?? ([], nil)
    }
    
    func isFirstLoad() -> Bool {
        return TSAuthenticatedReader.allClassesCached == nil
    }
    
    func processSelectedCell(_ index: IndexPath) {
        if index.item == 0 || (index.item == 1) || (index.item == 2) || (index.item == 3 && allClasses.count == 0) { return }
        
        let displayClass = allClasses[index.item - 3]
        let delegate = ClassDelegate(controller: controller, displayClass: displayClass)
        delegate.loadDataAndPushInController(controller)
    }
    
    func canHighlightCell(_ index: IndexPath) -> Bool {
        return index.item != 0 && index.item != 1 && index.item != 2 && (allClasses.count == 0 ? index.item != 3 : true)
    }
    
    func animateSelection(_ cell: UITableViewCell, indexPath: IndexPath, selected: Bool) {
        let background: UIColor = UIColor(white: 1.0, alpha: selected ? 0.3 : 0.0)
        
        UIView.animate(withDuration: 0.3, animations: {
            cell.backgroundColor = background
        })
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: TSSetTouchDelegateEnabledNotification), object: false)
        delay(0.5) {
            NotificationCenter.default.post(name: Notification.Name(rawValue: TSSetTouchDelegateEnabledNotification), object: true)
        }
    }
    
    func shouldIgnoreTouch(_ location: CGPoint, inCell: UITableViewCell) -> Bool {
        if let cell = inCell as? ClassNameCellWithSwitch {
            let switchFrame = cell.toggleSwitch.frame
            let minX = switchFrame.minX - 10
            let maxX = switchFrame.maxX + 10
            return location.x > minX && location.x < maxX
        }
        return false
    }
    
}
