//
//  ClassesView.swift
//  T-Square
//
//  Created by Cal on 8/27/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import UIKit

//MARK: View Controller and initial Delegate

let TSSetTouchDelegateEnabledNotification = "edu.gatech.cal.touchDelegateEnabled"
let TSBackNotification = "edu.gatech.cal.backTriggered"

class ClassesViewController : TableViewStackController, StackableTableDelegate, UIGestureRecognizerDelegate, UIDocumentInteractionControllerDelegate {

    var classes: [Class]?
    var loadingAnnouncements: Bool = true
    var announcements: [Announcement] = []
    var announcementIndexOffset: Int {
        get {
            return (announcements.count == 0 ? 2 : 1)
        }
    }
    var tableViewRestingPosition: CGPoint!
    @IBOutlet weak var bottomView: UIView!
    @IBOutlet weak var bottomViewHeight: NSLayoutConstraint!
    @IBOutlet var touchRecognizer: UITouchGestureRecognizer!
    @IBOutlet weak var collectionViewHeight: NSLayoutConstraint!
    @IBOutlet weak var activityIndicator: UIVisualEffectView!
    
    var documentController: UIDocumentInteractionController?
    
    //MARK: - Table View cell arrangement
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return (classes?.count ?? 0) + 2 }
        else { return announcements.count + (announcements.count == 0 ? 2 : 1) }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        if indexPath == nil { return 50.0 }
        
        if indexPath.section == 0 {
            if indexPath.item == 0 { return 50.0 }
            if indexPath.item == (classes?.count ?? 0) + 1 {
                return 40.0
            }
            return 70.0
        }
        if indexPath.section == 1 {
            return indexPath.item == 0 ? 40.0 : 60.0
        }
        return 50.0
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let index = indexPath.item
        let section = indexPath.section
        
        //classes
        if section == 0 {
            if index == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("settings") as! LogoutSettingsCell
                cell.decorate(TSAuthenticatedReader.username)
                cell.hideSeparator()
                return cell
            }
            if index == (classes?.count ?? 0) + 1 {
                let cell = tableView.dequeueReusableCellWithIdentifier("subtitle") as! TitleCell
                cell.decorate("View all classes")
                cell.hideSeparator()
                return cell
            }
            if let classes = classes {
                let displayClass = classes[index - 1]
                let cell = tableView.dequeueReusableCellWithIdentifier("class") as! ClassNameCell
                cell.decorate(displayClass)
                //if index == classes.count {
                //    cell.hideSeparator()
                //}
                return cell
            }
        }
        
        //announcements
        if section == 1 {
            if index == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("titleWithButton") as! TitleWithButtonCell
                cell.decorate("Recent Announcements", buttonText: "mark all read")
                return cell
            }
            if index == 1 && announcements.count == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("message") as! TitleCell
                cell.decorate(loadingAnnouncements ? "Loading Announcements..." : "No announcements posted.")
                return cell
            }
            let announcement = announcements[index - announcementIndexOffset]
            let cell = tableView.dequeueReusableCellWithIdentifier("announcement") as! AnnouncementCell
            cell.decorate(announcement)
            return cell
        }
        
        return tableView.dequeueReusableCellWithIdentifier("class")!
    }
    
    func reloadTable(centerTable: Bool = false) {
        self.tableView.reloadData()
        updateBottomView()
        
        if centerTable {
            let contentHeight = tableView.contentSize.height
            let availableHeight = self.view.frame.height
            if contentHeight < availableHeight {
                let difference = contentHeight - availableHeight
                collectionViewHeight.constant = difference * 0.9
            }
            else {
                collectionViewHeight.constant = 0.0
            }
            self.view.layoutIfNeeded()
        }
    }
    
    //MARK: - Handle announcements as they're loaded
    
    func addAnnouncements(newAnnouncements: [Announcement]) {
        let previous = self.announcements
        
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
        
        //trim to most recent
        let recentCount = iPad() ? 9 : 5
        
        if announcements.count > recentCount {
            let first = announcements.indices.first!
            let last = announcements.indices.last!
            announcements.removeRange(first.advancedBy(recentCount)...last)
        }
        
        //don't animate if this delegate isn't visible anymore
        if delegateStack.count != 0 { return }
        
        tableView.beginUpdates()
        
        if previous.count == 0 && announcements.count != 0 {
            //remove "Loading Announcements..."
            tableView.deleteRowsAtIndexPaths([NSIndexPath(forItem: 1, inSection: 1)], withRowAnimation: UITableViewRowAnimation.Left)
        }
        
        //animate
        for i in 0 ..< recentCount {
            if previous.count > i && !(announcements as NSArray).containsObject(previous[i]) {
                tableView.deleteRowsAtIndexPaths([NSIndexPath(forItem: i + 1, inSection: 1)], withRowAnimation: UITableViewRowAnimation.Top)
            }
            
            if announcements.count > i && !(previous as NSArray).containsObject(announcements[i]) {
                tableView.insertRowsAtIndexPaths([NSIndexPath(forItem: i + 1, inSection: 1)], withRowAnimation:  UITableViewRowAnimation.Middle)
            }
        }

        tableView.endUpdates()
        let countBefore = previous.count == 0 ? 1 : previous.count
        let countAfter = announcements.count
        let cellHeight: CGFloat = 60.0
        updateBottomView(offset: CGFloat(countAfter - countBefore) * cellHeight)
        
    }
    
    func doneLoadingAnnoucements() {
        loadingAnnouncements = false
        reloadTable()
    }
    
    //MARK: - Customization of the view
    
    override func viewDidAppear(animated: Bool) {
        tableViewRestingPosition = tableView.frame.origin
        updateBottomView()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "setTouchDelegateEnabled:", name: TSSetTouchDelegateEnabledNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "backTriggered", name: TSBackNotification, object: nil)
        
        activityIndicator.hidden = false
        activityIndicator.layer.cornerRadius = 25.0
        activityIndicator.layer.masksToBounds = true
        activityIndicator.transform = CGAffineTransformMakeScale(0.0, 0.0)
    }
    
    override func viewDidDisappear(animated: Bool) {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        updateBottomView()
        
        NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: false)
        delay(0.5) {
            NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: true)
        }
    }
    
    func updateBottomView(offset offset: CGFloat = 0) {
        let contentHeight = tableView.contentSize.height + offset
        let scroll = tableView.contentOffset.y
        let height = tableView.frame.height
        
        let viewHeight = max(0, height - (contentHeight - scroll))
        bottomViewHeight.constant = viewHeight
        if offset == 0 {
            self.view.layoutIfNeeded()
        }
        else {
            UIView.animateWithDuration(0.35, animations: {
                self.view.layoutIfNeeded()
            })
        }
    }
    
    //MARK: - User Interaction
    
    @IBAction func touchDown(sender: UITapGestureRecognizer) {
        let touch = sender.locationInView(tableView)
        self.processTouchInTableView(touch, state: sender.state)
    }
    
    @IBAction func viewPanned(sender: UIPanGestureRecognizer) {
        if delegateStack.count == 0 { return }
        
        if sender.state == .Began {
            tableViewRestingPosition = tableView.frame.origin
        }
        
        if sender.state == .Ended {
            tableView.scrollEnabled = true
            tableView.userInteractionEnabled = true
            
            let newTablePosition = tableViewRestingPosition
            let newBottomPosition = CGPointMake(tableViewRestingPosition.x, bottomView.frame.origin.y)
            
            if sender.velocityInView(self.tableView).x < 0 {
                //if they were swiping back towards the left, do nothing
                UIView.animateWithDuration(0.3, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [], animations: {
                    self.tableView.frame.origin = newTablePosition
                    self.bottomView.frame.origin = newBottomPosition
                }, completion: nil)
                return
            }
            
            let endPosition = self.tableView.frame.origin.x
            self.tableView.frame.origin = newTablePosition
            self.bottomView.frame.origin = newBottomPosition
            
            if endPosition > tableViewRestingPosition.x + 10.0 {
                self.popDelegate()
            }
            else {
                self.unhighlightAllCells()
            }
            return
        }
        
        //do nothing for vertical scrolling
        let velocity = sender.velocityInView(self.tableView)
        if 2 * abs(velocity.y) > abs(velocity.x) { return }
        
        tableView.scrollEnabled = false
        tableView.userInteractionEnabled = false
        let translation = sender.translationInView(self.view)
        self.tableView.frame.origin = CGPointMake(max(tableViewRestingPosition.x, tableViewRestingPosition.x + translation.x), 0.0)
        self.bottomView.frame.origin = CGPointMake(max(tableViewRestingPosition.x, tableViewRestingPosition.x + translation.x), bottomView.frame.origin.y)
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func animateSelection(cell: UITableViewCell, indexPath: NSIndexPath, selected: Bool) {
        let background: UIColor
        if indexPath.section == 0 {
            if indexPath.item == 0 { return }
            background = UIColor(white: 1.0, alpha: selected ? 0.3 : 0.0)
        }
        else { //if section == 1
            if indexPath.item == 0 { return }
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
    
    func setTouchDelegateEnabled(notification: NSNotification) {
        if let enabled = notification.object as? Bool {
            touchRecognizer.enabled = enabled
            
            if !enabled {
                for cell in tableView.visibleCells {
                    let index = tableView.indexPathForCell(cell)!
                    if let delegate = tableView.delegate as? StackableTableDelegate where delegate.canHighlightCell(index) == true {
                        delegate.animateSelection(cell, indexPath: index, selected: false)
                    }
                }
            }
        }
        
        updateBottomView()
    }
    
    @IBAction func backTriggered() {
        popDelegate()
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        delay(0.01) {
            self.reloadTable()
        }
    }
    
    //MARK: - Stackable Table Delegate methods
    
    func processSelectedCell(index: NSIndexPath) {
        if index.section == 0 {
            if index.item == 0 { return }
            if index.item == (classes?.count ?? 0) + 1 {
                //load extra classes
                if TSAuthenticatedReader.allClasses == nil {
                    setActivityIndicatorVisible(true)
                }
                
                dispatch_async(TSNetworkQueue) {
                    let allClasses = TSAuthenticatedReader.getAllClasses()
                    let delegate = AllClassesDelegate(allClasses: allClasses, controller: self)
                    sync() {
                        self.pushDelegate(delegate)
                        self.setActivityIndicatorVisible(false)
                    }
                }
                
                return
            }
            
            //show class
            guard let classes = classes else { return }
            let displayClass = classes[index.item - 1]
            pushDelegate(ClassDelegate(controller: self, displayClass: displayClass))
        }
        
        if index.section == 1 {
            if index.item == 0 {
                markAllAnnouncementsRead()
                return
            }
            if index.item == 1 && announcements.count == 0 { return }
            let announcement = announcements[index.item - 1]
            AnnouncementCell.presentAnnouncement(announcement, inController: self)
        }
    }
    
    func usesBottomView(delegate: AnyObject) -> Bool {
        return delegate is ClassesViewController
            || delegate is AnnouncementDelegate
            || delegate is ClassDelegate
    }
    
    override func pushDelegate(delegate: StackableTableDelegate) {
        bottomView.hidden = !(usesBottomView(delegate))
        super.pushDelegate(delegate)
        updateBottomView()
        let timingFunction = CAMediaTimingFunction(controlPoints: 0.215, 0.61, 0.355, 1)
        playTransitionForView(bottomView, duration: 0.4, transition: kCATransitionPush, subtype: kCATransitionFromRight, timingFunction: timingFunction)
    }
    
    override func popDelegate() {
        super.popDelegate()
        let delegate = tableView.delegate!
        bottomView.hidden = !(usesBottomView(delegate))
        updateBottomView()
        let timingFunction = CAMediaTimingFunction(controlPoints: 0.215, 0.61, 0.355, 1)
        playTransitionForView(bottomView, duration: 0.4, transition: kCATransitionPush, subtype: kCATransitionFromLeft, timingFunction: timingFunction)
    }
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        return index != NSIndexPath(forItem: 0, inSection: 1)
    }
    
    //MARK: - Auxillary Functions
    
    func markAllAnnouncementsRead() {
        guard let classes = classes else { return }
        for currentClass in classes {
            for announcement in currentClass.announcements {
                if !announcement.hasBeenRead() {
                    announcement.markRead()
                }
            }
        }
        self.reloadTable()
    }
    
    func presentDocumentFromURL(webURL: NSURL) {
        self.setActivityIndicatorVisible(true)
        
        dispatch_async(TSNetworkQueue, {
            let data = NSData(contentsOfURL: webURL)!
            
            //get the URL's file extension
            let splits = webURL.path!.componentsSeparatedByString(".")
            let fileType = splits.last!
            
            //get URL to save to
            let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
            let documents = paths[0] as NSString
            let fileURLpath = documents.stringByAppendingPathComponent("Attachment.\(fileType)")
            data.writeToFile(fileURLpath, atomically: false)
            let fileURL = NSURL(fileURLWithPath: fileURLpath)
            
            sync() {
                let controller = UIDocumentInteractionController(URL: fileURL)
                self.documentController = controller
                controller.delegate = self
                controller.presentPreviewAnimated(true)
                delay(0.5) {
                    self.setActivityIndicatorVisible(false)
                }
            }
            
        })
    }
    
    func documentInteractionControllerViewControllerForPreview(controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    func openFromLinks(links: [String]) {
        if links.count == 0 { return }
        if links.count == 1 {
            let alert = UIAlertController(title: "Open link in Safari?", message: websiteForLink(links[0]) + "/...", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .Destructive, handler: nil))
            alert.addAction(UIAlertAction(title: "Open", style: .Default, handler: { _ in
                UIApplication.sharedApplication().openURL(NSURL(string: links[0])!)
            }))
            self.presentViewController(alert, animated: true, completion: nil)
            return
        }
        
        let alert = UIAlertController(title: "Open link in Safari?", message: "There are multiple links in this message. Which would you like to open?", preferredStyle: .Alert)
        for link in links {
            alert.addAction(UIAlertAction(title: websiteForLink(link) + "/...", style: .Default, handler: { _ in
                UIApplication.sharedApplication().openURL(NSURL(string: link)!)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .Destructive, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func setActivityIndicatorVisible(visible: Bool) {
        let scale: CGFloat = visible ? 1.0 : 0.1
        let transform = CGAffineTransformMakeScale(scale, scale)
        
        UIView.animateWithDuration(visible ? 0.7 : 0.4, delay: 0.0, usingSpringWithDamping: visible ? 0.5 : 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.activityIndicator.transform = transform
            self.activityIndicator.alpha = visible ? 1.0 : 0.0
        }, completion: nil)
    }
    
}
