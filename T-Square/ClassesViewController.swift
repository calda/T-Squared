//
//  ClassesViewController.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 8/27/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation
import UIKit
import SafariServices
import MessageUI

//MARK: View Controller and initial Delegate

let TSSetTouchDelegateEnabledNotification = "edu.gatech.cal.touchDelegateEnabled"
let TSPerformingNetworkActivityNotification = "edu.gatech.cal.performingNetworkActivity"
let TSBackPressedNotification = "edu.gatech.cal.backTriggered"
let TSBackButtonPressCountKey = "edu.gatech.cal.backButtonCount"
let TSNetworkErrorNotification = "edu.gatech.cal.networkerror"
let TSShowSettingsNotification = "edu.gatech.cal.showSettings"

let TSHideClassCountPopupKey = "edu.gatech.cal.hideClassCountPopup"

class ClassesViewController : TableViewStackController, StackableTableDelegate, UIGestureRecognizerDelegate, UIDocumentInteractionControllerDelegate, MFMailComposeViewControllerDelegate {

    var classes: [Class]?
    var classOffsetCount: Int {
        return 1 + (tooManyClassesIndex == nil ? 0 : 1)
    }
    var tooManyClassesIndex: NSIndexPath? = nil
    
    var loadingAnnouncements: Bool = true
    var announcements: [Announcement] = []
    var recentAnnouncementsCell: TitleWithButtonCell?
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
    var refreshControl: UIRefreshControl!
    
    var activityIndicator: UIView! {
        return loginController.activityCircle
    }
    var loginController: LoginViewController!
    var documentController: UIDocumentInteractionController?
    
    //MARK: - Table View cell arrangement
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //this feature has been transitioned in to a the reloadDataIfNecessary method on StackableTableDelegate
        //it is not applicable to all Delegates instead of just this one
        //reloadClassesIfDroppedFromMemory()
        
        if !NSUserDefaults.standardUserDefaults().boolForKey(TSHideClassCountPopupKey) {
            tooManyClassesIndex = classes?.count > 8 ? NSIndexPath(forItem: 1, inSection: 0) : nil
        }
        
        
        if section == 0 { return (classes?.count ?? 0) + classOffsetCount + 1 }
        else { return announcements.count + (announcements.count == 0 ? 2 : 1) }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        if indexPath == nil { return 50.0 }
        
        if indexPath.section == 0 {
            if indexPath.item == 0 { return 50.0 }
            if indexPath == tooManyClassesIndex { return 100.0 }
            if indexPath.item == (classes?.count ?? 0) + classOffsetCount { //all classes cell
                return 50.0
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
                cell.decorate(TSAuthenticatedReader?.username ?? "username")
                cell.hideSeparator()
                return cell
            }
            
            if indexPath == tooManyClassesIndex {
                let cell = tableView.dequeueReusableCellWithIdentifier("tooManyClasses")!
                cell.hideSeparator()
                return cell
            }
            
            if index == (classes?.count ?? 0) + classOffsetCount {
                let cell = tableView.dequeueReusableCellWithIdentifier("subtitle") as! TitleCell
                cell.decorate("View all classes")
                cell.hideSeparator()
                return cell
            }
            if let classes = classes {
                let displayClass = classes[index - classOffsetCount]
                let cell = tableView.dequeueReusableCellWithIdentifier("classWithIcon") as! ClassNameCell
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
                recentAnnouncementsCell = cell
                
                //only show button if there is an unread announcement
                cell.button.hidden = true
                for ann in self.announcements {
                    if !ann.hasBeenRead() {
                        recentAnnouncementsCell?.button?.hidden = false
                        break
                    }
                }
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
        
        return tableView.dequeueReusableCellWithIdentifier("classWithIcon")!
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
    
    func loadAnnouncements(reloadClasses reloadClasses: Bool = true) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSPerformingNetworkActivityNotification, object: true, userInfo: nil)
        if reloadClasses { self.classes = TSAuthenticatedReader.getActiveClasses() }
        
        self.announcements = []
        self.loadingAnnouncements = true
        
        if self.classes == nil || self.classes?.count == 0 {
            //no classes to load from
            //there are systems in place that *should* prevent the code from
            //reaching this far when the classes aren't loaded out of error
            
            self.doneLoadingAnnoucements()
        }
        
        var doneLoadingCount = 0
        let necessaryCount = self.classes!.count
        
        for currentClass in self.classes ?? [] {
            if TSAuthenticatedReader == nil { break }
            //load announcements as fast as possible
            dispatch_async(TSNetworkQueue) {
                let announcements = TSAuthenticatedReader.getAnnouncementsForClass(currentClass)
                
                func markLoadedAndCheckIfDone() -> Bool {
                    doneLoadingCount += 1
                    return doneLoadingCount == necessaryCount
                }
                
                self.addAnnouncements(announcements)
                if markLoadedAndCheckIfDone() {
                    sync { self.doneLoadingAnnoucements() }
                }
            }
        }
        
    }
    
    func addAnnouncements(newAnnouncements: [Announcement]) {
        
        for ann in newAnnouncements {
            announcements.append(ann)
        }
        
        //resort
        announcements.sortInPlace({ ann1, ann2 in
            if let date1 = ann1.date, let date2 = ann2.date {
                return date1.timeIntervalSinceDate(date2) > 0
            }
            return false
        })
        
        //trim to most recent
        let recentCount = iPad() ? 10 : 5
        
        if announcements.count > recentCount {
            let first = announcements.indices.first!
            let last = announcements.indices.last!
            announcements.removeRange(first.advancedBy(recentCount)...last)
        }
    }
    
    func doneLoadingAnnoucements() {
        loadingAnnouncements = false
        NSNotificationCenter.defaultCenter().postNotificationName(TSPerformingNetworkActivityNotification, object: false)
        
        if announcements.count == 0 { self.reloadTable() }
        
        //animate the announcements
        //don't animate if this delegate isn't visible anymore
        if delegateStack.count != 0 { return }
        
        tableView.beginUpdates()
        
        if announcements.count != 0 {
            //remove "Loading Announcements..."
            tableView.deleteRowsAtIndexPaths([NSIndexPath(forItem: 1, inSection: 1)], withRowAnimation: UITableViewRowAnimation.Left)
        }
        
        //animate
        let recentCount = iPad() ? 10 : 5
        let previous: [Announcement] = []
        
        for i in 0 ..< recentCount {
            if previous.count > i && !(announcements as NSArray).containsObject(previous[i]) {
                tableView.deleteRowsAtIndexPaths([NSIndexPath(forItem: i + 1, inSection: 1)], withRowAnimation: UITableViewRowAnimation.Top)
            }
            
            if announcements.count > i && !(previous as NSArray).containsObject(announcements[i]) {
                tableView.insertRowsAtIndexPaths([NSIndexPath(forItem: i + 1, inSection: 1)], withRowAnimation:  UITableViewRowAnimation.Middle)
            }
        }
        
        tableView.endUpdates()
        let countBefore = 1
        let countAfter = max(1, announcements.count)
        let cellHeight: CGFloat = 60.0
        
        let offsetCount = countAfter - countBefore
        if offsetCount != 0 {
            updateBottomView(offset: CGFloat(offsetCount) * cellHeight)
        }
        
        //reload Recent Announcements cell
        //so that "mark all read" can appear if necessary
        tableView.reloadRowsAtIndexPaths([NSIndexPath(forItem: 0, inSection: 1)], withRowAnimation: UITableViewRowAnimation.None)
    }
    
    //MARK: - Customization of the view
    
    override func viewDidLoad() {
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "tableRefreshed:", forControlEvents: .ValueChanged)
        tableView.addSubview(refreshControl)
    }
    
    override func viewWillAppear(animated: Bool) {
        tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 30.0, right: 0.0)
    }
    
    override func viewDidAppear(animated: Bool) {
        tableViewRestingPosition = tableView.frame.origin
        updateBottomView()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "setTouchDelegateEnabled:", name: TSSetTouchDelegateEnabledNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "backTriggeredFromButtonPress", name: TSBackPressedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "scrollToTop", name: TSStatusBarTappedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "pushSettingsDelegate", name: TSShowSettingsNotification, object: nil)
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
        //update the bottom view
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
        
        //also update the refresh control's alpha
        //1.0 alpha when scroll = -65
        var alpha: CGFloat = 0.0
        if scroll < -10.0 {
            alpha = min(1.0, (scroll + 10.0) / -75.0)
        }
        refreshControl.alpha = alpha
    }
    
    //MARK: - User Interaction
    
    var panning = false
    
    @IBAction func viewPanned(sender: UIPanGestureRecognizer) {
        //do nothing for vertical scrolling until panning actually starts
        if !panning {
            let velocity = sender.velocityInView(self.tableView)
            if 2 * abs(velocity.y) > abs(velocity.x) { return }
        }
        
        if sender.state == .Began {
            
            //don't start a pan if this touch is ignored by the delegate
            let touch = sender.locationInView(tableView)
            if let indexPath = tableView.indexPathForRowAtPoint(touch),
               let cell = tableView.cellForRowAtIndexPath(indexPath) {
                
                if (tableView.delegate as? StackableTableDelegate)?.shouldIgnoreTouch?(touch, inCell: cell) == true {
                    return
                }
            }
            
            panning = true
            NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: false)
            tableViewRestingPosition = tableView.frame.origin
        }
        
        if !panning { return }
        
        if sender.state == .Ended {
            NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: true)
            panning = false
        }
        
        if delegateStack.count == 0 {
            return
        }
        
        if sender.state == .Ended {
            tableView.scrollEnabled = true
            tableView.userInteractionEnabled = true
            
            let newTablePosition = tableViewRestingPosition
            let newBottomPosition = CGPointMake(tableViewRestingPosition.x, bottomView.frame.origin.y)
            
            if sender.velocityInView(self.tableView).x <= 0 {
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
                
                //stop the "you can swipe" popup from ever showing up
                //because the user clearly knows it's possible
                let data = NSUserDefaults.standardUserDefaults()
                data.setInteger(11, forKey: TSBackButtonPressCountKey)
            }
            else {
                self.unhighlightAllCells()
            }
            return
        }
        
        tableView.scrollEnabled = false
        tableView.userInteractionEnabled = false
        let translation = sender.translationInView(self.view)
        self.tableView.frame.origin = CGPointMake(max(tableViewRestingPosition.x, tableViewRestingPosition.x + translation.x), 0.0)
        self.bottomView.frame.origin = CGPointMake(max(tableViewRestingPosition.x, tableViewRestingPosition.x + translation.x), bottomView.frame.origin.y)
    }
    
    @IBAction func touchDown(sender: UITapGestureRecognizer) {
        let touch = sender.locationInView(tableView)
        self.processTouchInTableView(touch, state: sender.state)
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
    
    func backTriggeredFromButtonPress() {
     
        let data = NSUserDefaults.standardUserDefaults()
        let pressCount = min(data.integerForKey(TSBackButtonPressCountKey) + 1, 11)
        data.setInteger(pressCount, forKey: TSBackButtonPressCountKey)
        
        if pressCount == 10 {
            let alert = UIAlertController(title: "", message: "Did you know you can swipe right at any time to go back?", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Awesome!", style: .Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
        }
        
        else {
            backTriggered()
        }
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        delay(0.01) {
            self.reloadTable()
        }
    }
    
    func tableRefreshed(refresh: UIRefreshControl) {
        guard let delegate = tableView.delegate as? StackableTableDelegate else {
            refresh.endRefreshing()
            return
        }
        
        delegate.loadData()
        tableView.reloadData()
        delay(0.3) {
            refresh.endRefreshing()
        }
    }
    
    func scrollToTop() {
        tableView.setContentOffset(CGPointZero, animated: true)
    }
    
    //MARK: - Stackable Table Delegate methods
    
    func processSelectedCell(index: NSIndexPath) {
        print("SHOULD NOT BE CALLED")
        return //unused in favor of processSelectedCellWithTouch
    }
    
    func processSelectedCellWithTouch(index: NSIndexPath, _ touchLocationInCell: CGPoint) {
        if index.section == 0 {
            if index.item == 0 { return }
            if index.item == (classes?.count ?? 0) + classOffsetCount {
                let delegate = AllClassesDelegate(controller: self)
                delegate.loadDataAndPushInController(self)
                return
            }
            
            //"That's a lot of classes" popup
            if index == tooManyClassesIndex {
                if let cell = tableView.cellForRowAtIndexPath(index) as? BalloonPopupCell {
                    let action = cell.actionForTouch(touchLocationInCell)
                    
                    if action == .Action {
                        let delegate = AllClassesDelegate(controller: self)
                        delegate.loadDataAndPushInController(self)
                        return
                    }
                    else if action == .Cancel {
                        //remove cell
                        let indexToRemove = tooManyClassesIndex!
                        tooManyClassesIndex = nil
                        NSUserDefaults.standardUserDefaults().setBool(true, forKey: TSHideClassCountPopupKey)
                        tableView.deleteRowsAtIndexPaths([indexToRemove], withRowAnimation: .Fade)
                        delay(1.0) {
                            NSUserDefaults.standardUserDefaults().setBool(false, forKey: TSHideClassCountPopupKey)
                        }
                        
                    }
                }
                return
            }
            
            //show class
            guard let classes = classes else { return }
            
            let displayClass = classes[index.item - classOffsetCount]
            let delegate = ClassDelegate(controller: self, displayClass: displayClass)
            delegate.loadDataAndPushInController(self)
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
    
    var DISABLE_PUSHES = false {
        didSet {
            if DISABLE_PUSHES {
                delay(1.0) {
                    self.DISABLE_PUSHES = false
                }
            }
        }
    }
    
    func pushDelegate(delegate: StackableTableDelegate, ifCurrentMatchesExpected expected: UITableViewDelegate) {
        if expected === tableView.delegate {
            pushDelegate(delegate)
        }
    }
    
    private func pushDelegate(delegate: StackableTableDelegate) {
        pushDelegate(delegate, hasBeenUpdatedToNewLoadFormat: true)
    }
    
    override func pushDelegate(delegate: StackableTableDelegate, hasBeenUpdatedToNewLoadFormat: Bool) {
        if DISABLE_PUSHES { return }
        
        bottomView.hidden = !(usesBottomView(delegate))
        super.pushDelegate(delegate, hasBeenUpdatedToNewLoadFormat: true)
        updateBottomView()
        let timingFunction = CAMediaTimingFunction(controlPoints: 0.215, 0.61, 0.355, 1)
        playTransitionForView(bottomView, duration: 0.4, transition: kCATransitionPush, subtype: kCATransitionFromRight, timingFunction: timingFunction)
    }
    
    override func popDelegate() {
        
        self.setActivityIndicatorVisible(false) //terminate any other loading (even though it'll continue in the background)
        
        super.popDelegate()
        let delegate = tableView.delegate!
        (delegate as? StackableTableDelegate)?.reloadDataIfNecessary(self)
        bottomView.hidden = !(usesBottomView(delegate))
        updateBottomView()
        let timingFunction = CAMediaTimingFunction(controlPoints: 0.215, 0.61, 0.355, 1)
        playTransitionForView(bottomView, duration: 0.4, transition: kCATransitionPush, subtype: kCATransitionFromLeft, timingFunction: timingFunction)
    }
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        return index != NSIndexPath(forItem: 0, inSection: 1)
    }
    
    func loadData() {
        if self.loadingAnnouncements { return }
        loadAnnouncements()
    }
    
    func loadCachedData() {
        self.classes = TSAuthenticatedReader.classes ?? []
        reloadClassesIfDroppedFromMemory()
    }
    
    func reloadClassesIfDroppedFromMemory() {
        if TSAuthenticatedReader == nil { return }
        let noClassesLoaded = TSAuthenticatedReader.classes == nil || TSAuthenticatedReader.classes!.count == 0 || classes?.count == 0
        let shouldHaveClasses = !TSAuthenticatedReader.actuallyHasNoClasses
        
        if noClassesLoaded && shouldHaveClasses && !loadingAnnouncements {
            print("RELOADING CLASSES (dropped from memory)")
            loadAnnouncements() //restart the loading process, because we somehow dropped the classes from memory
        }
    }
    
    func isFirstLoad() -> Bool {
        return TSAuthenticatedReader.classes == nil || (TSAuthenticatedReader.classes?.count == 0 && !TSAuthenticatedReader.actuallyHasNoClasses)
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
        recentAnnouncementsCell?.button?.hidden = true
    }
    
    func presentDocumentFromURL(webURL: NSURL, name: String = "Attachment") {
        self.setActivityIndicatorVisible(true)
        
        dispatch_async(TSNetworkQueue, {
            guard let data = NSData(contentsOfURL: webURL) else {
                NSNotificationCenter.defaultCenter().postNotificationName(TSNetworkErrorNotification, object: nil)
                self.setActivityIndicatorVisible(false)
                return
            }
            
            //get the URL's file extension
            let splits = webURL.path!.componentsSeparatedByString(".")
            let fileType = splits.last!
            
            //get URL to save to
            let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
            let documents = paths[0] as NSString
            let fileURLpath = documents.stringByAppendingPathComponent("\(name).\(fileType)")
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
        
        func shortSiteForLink(link: String) -> String {
            let shortWebsite = websiteForLink(link)
            //handle duplicates
            var countMatching = 0
            var thisCount = 1
            for other in links {
                let otherShort = websiteForLink(other)
                if otherShort == shortWebsite {
                    countMatching++
                }
                if other == link {
                    thisCount = countMatching
                }
            }
            
            return shortWebsite + (countMatching > 1 ? "\(thisCount)" : "")
        }
        
        if links.count == 0 { return }
        if links.count == 1 {
            let alert = UIAlertController(title: "Open link?", message: websiteForLink(links[0]), preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .Destructive, handler: nil))
            alert.addAction(UIAlertAction(title: "Open", style: .Default, handler: { _ in
                self.openLinkInWebView(links[0], title: websiteForLink(links[0]))
            }))
            self.presentViewController(alert, animated: true, completion: nil)
            return
        }
        
        let alert = UIAlertController(title: "Open link?", message: "There are multiple links in this message. Which would you like to open?", preferredStyle: .Alert)
        for link in links {
            alert.addAction(UIAlertAction(title: shortSiteForLink(link), style: .Default, handler: { _ in
                self.openLinkInWebView(link, title: websiteForLink(link))
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .Destructive, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func openLinkInWebView(link: String, title: String) {
        guard let URL = NSURL(string: link) else {
            let alert = UIAlertController(title: "Could not open link.", message: "We had a problem opening that link. (\(link))", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "ok", style: .Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
            return
        }
        
        loginController.presentWebViewWithURL(URL, title: title)
    }
    
    func openTextInSafari(text: String, title: String) {
        loginController.presentWebViewWithText(text, title: title)
    }
    
    func setActivityIndicatorVisible(visible: Bool) {
        let scale: CGFloat = visible ? 1.0 : 0.1
        let transform = CGAffineTransformMakeScale(scale, scale)
        
        UIView.animateWithDuration(visible ? 0.7 : 0.4, delay: 0.0, usingSpringWithDamping: visible ? 0.5 : 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.loginController.activityCircle.transform = transform
            self.loginController.activityCircle.alpha = visible ? 1.0 : 0.0
        }, completion: nil)
    }
    
    func pushSettingsDelegate() {
        pushDelegate(SettingsDelegate(controller: self), hasBeenUpdatedToNewLoadFormat: true)
    }
    
    func openContactEmail() {
        if !MFMailComposeViewController.canSendMail() {
            let alert = UIAlertController(title: "Cannot Send Mail", message: "You mail account is not set up correctly.", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
        }
        let mail = MFMailComposeViewController()
        mail.setToRecipients(["cal@calstephens.tech"])
        mail.setSubject("T-Squared Support for Version \(NSBundle.applicationVersionNumber) (\(NSBundle.applicationBuildNumber))")
        mail.mailComposeDelegate = self
        self.presentViewController(mail, animated: true, completion: nil)
    }
    
    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        controller.dismissViewControllerAnimated(true, completion: nil)
    }
    
}

extension StackableTableDelegate {
    
    var indexPathsForHeader: [NSIndexPath] {
        return [NSIndexPath(forItem: 0, inSection: 0)]
    }
    
    func loadDataAndPushInController(controller: ClassesViewController) {
        let previousDelegate: UITableViewDelegate! = controller.tableView.delegate
        
        let firstLoad = isFirstLoad()
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        if (firstLoad) {
            controller.setActivityIndicatorVisible(true)
        }
        
        if !firstLoad {
            self.loadCachedData()
            controller.pushDelegate(self)
            NSNotificationCenter.defaultCenter().postNotificationName(TSPerformingNetworkActivityNotification, object: true)
        }
        
        dispatch_async(TSNetworkQueue, {
            self.loadData()
            
            sync {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                if controller.activityIndicator.alpha == 1.0 && !(self is AnnouncementDelegate) {
                    controller.setActivityIndicatorVisible(false)
                }
                NSNotificationCenter.defaultCenter().postNotificationName(TSPerformingNetworkActivityNotification, object: false)
                
                if firstLoad {
                    controller.pushDelegate(self, ifCurrentMatchesExpected: previousDelegate)
                }
                else {
                    if controller.tableView.delegate === self {
                        controller.tableView.reloadData()
                    }
                }
            }
        })
        
    }
    
    func reloadDataIfNecessary(controller: ClassesViewController) {
        if isFirstLoad() {
            print("RELOADING DATA for the popped delegate. Something went missing.")
            
            controller.setActivityIndicatorVisible(true)
            dispatch_async(TSNetworkQueue) {
                self.loadData()
                sync() {
                    controller.reloadTable()
                    controller.setActivityIndicatorVisible(false)
                }
            }
            
        }
    }
    
}
