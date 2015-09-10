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
        if section == 0 { return (classes?.count ?? 0) + 1 }
        else { return announcements.count + (announcements.count == 0 ? 2 : 1) }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        if indexPath == nil { return 50.0 }
        
        if indexPath.section == 0 {
            if indexPath.item == 0 { return 50.0 }
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
                cell.hideSeparator()
                return cell
            }
            if let classes = classes {
                let displayClass = classes[index - 1]
                let cell = tableView.dequeueReusableCellWithIdentifier("class") as! ClassNameCell
                cell.decorate(displayClass)
                if index == classes.count {
                    cell.hideSeparator()
                }
                return cell
            }
        }
        
        //announcements
        if section == 1 {
            if index == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("title") as! TitleCell
                cell.decorate("Recent Announcements")
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
        
        //trim to most recent 5
        if announcements.count > 5 {
            let first = announcements.indices.first!
            let last = announcements.indices.last!
            announcements.removeRange(first.advancedBy(5)...last)
        }
        
        self.reloadTable()
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
    
    func updateBottomView() {
        let contentHeight = tableView.contentSize.height
        let scroll = tableView.contentOffset.y
        let height = tableView.frame.height
        
        let viewHeight = max(0, height - (contentHeight - scroll))
        bottomViewHeight.constant = viewHeight
        self.view.layoutIfNeeded()
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
    
    //MARK: - Stackable Table Delegate methods
    
    func processSelectedCell(index: NSIndexPath) {
        if index.section == 0 {
            if index.item == 0 { return }
            guard let classes = classes else { return }
            let displayClass = classes[index.item - 1]
            pushDelegate(ClassDelegate(controller: self, displayClass: displayClass))
        }
        
        if index.section == 1 {
            if index.item == 0 { return }
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
        playTransitionForView(bottomView, duration: 0.3, transition: kCATransitionPush, subtype: kCATransitionFromRight)
    }
    
    override func popDelegate() {
        super.popDelegate()
        let delegate = tableView.delegate!
        bottomView.hidden = !(usesBottomView(delegate))
        updateBottomView()
        playTransitionForView(bottomView, duration: 0.3, transition: kCATransitionPush, subtype: kCATransitionFromLeft)
    }
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        return index != NSIndexPath(forItem: 0, inSection: 1)
    }
    
    //MARK: - Auxillary Functions
    
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
