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
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


//MARK: View Controller and initial Delegate

let TSSetTouchDelegateEnabledNotification = "edu.gatech.cal.touchDelegateEnabled"
let TSPerformingNetworkActivityNotification = "edu.gatech.cal.performingNetworkActivity"
let TSBackPressedNotification = "edu.gatech.cal.backTriggered"
let TSNetworkErrorNotification = "edu.gatech.cal.networkerror"
let TSShowSettingsNotification = "edu.gatech.cal.showSettings"

let TSHideClassCountPopupKey = "edu.gatech.cal.hideClassCountAlert_2"
let TSNeverShowRateAlertKey = "edu.gatech.cal.hideRateAlert_1"
let TSLoginCountKey = "edu.gatech.cal.loginCount"

class ClassesViewController : TableViewStackController, StackableTableDelegate, UIGestureRecognizerDelegate, UIDocumentInteractionControllerDelegate, MFMailComposeViewControllerDelegate {

    var classes: [Class]?
    var classOffsetCount: Int {
        return 1 + [tooManyClassesIndex, rateIndex, backToGTPortalIndex].filter{ $0 != nil }.count
    }
    
    var backToGTPortalIndex: IndexPath? = nil
    var tooManyClassesIndex: IndexPath? = nil
    var rateIndex: IndexPath? = nil
    var alertHidden = false
    
    var loadingAnnouncements: Bool = true
    var announcements: [Announcement] = []
    var recentAnnouncementsCell: TitleWithButtonCell?
    var announcementIndexOffset: Int {
        return (announcements.count == 0 ? 2 : 1)
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
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        //decide what alert to show
        backToGTPortalIndex = TSWasLaunchedFromGTPortal ? IndexPath(item: 0, section: 0) : nil
        
        if !alertHidden {
            if !UserDefaults.standard.bool(forKey: TSHideClassCountPopupKey) {
                let index = TSWasLaunchedFromGTPortal ? 2 : 1
                if classes?.count > 8 {
                    tooManyClassesIndex = IndexPath(item: index, section: 0)
                    rateIndex = nil //only one can be active. this takes precendnce.
                    //take about some crazy spaghetti code with mutable state. this should really be done better.
                } else {
                    tooManyClassesIndex = nil
                }
            }
            
            if tooManyClassesIndex == nil && !UserDefaults.standard.bool(forKey: TSNeverShowRateAlertKey) {
                let index = TSWasLaunchedFromGTPortal ? 2 : 1
                let loginCount = UserDefaults.standard.integer(forKey: TSLoginCountKey)
                
                if loginCount % 15 == 0 && loginCount > 0 {
                    rateIndex = IndexPath(item: index, section: 0)
                } else {
                    rateIndex = nil
                }
            }
        }
        
        if section == 0 {
            return (classes?.count ?? 0) + classOffsetCount + 1
        } else {
            let showingAnnouncements = !(announcements.count == 0) && !self.loadingAnnouncements
            return (!showingAnnouncements ? 2 : announcements.count + 1)
        }
    }
    
    func numberOfSectionsInTableView(_ tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, heightForRowAtIndexPath indexPath: IndexPath!) -> CGFloat {
        if indexPath == nil { return 50.0 }
        
        if indexPath.section == 0 {
            if indexPath.item == (backToGTPortalIndex == nil ? 0 : 1) { return 50.0 }
            if indexPath == tooManyClassesIndex || indexPath == rateIndex { return 100.0 }
            if indexPath == backToGTPortalIndex { return 30.0 }
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
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let index = indexPath.item
        let section = indexPath.section
        
        //classes
        if section == 0 {
            
            if indexPath == backToGTPortalIndex {
                let cell = tableView.dequeueReusableCell(withIdentifier: "title") as! TitleCell
                cell.decorate("Back to GT Portal")
                return cell
            }
            
            if index == (backToGTPortalIndex == nil ? 0 : 1) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "settings") as! LogoutSettingsCell
                cell.decorate(TSAuthenticatedReader?.username ?? "username")
                cell.hideSeparator()
                return cell
            }
            
            if indexPath == tooManyClassesIndex {
                let cell = tableView.dequeueReusableCell(withIdentifier: "tooManyClasses")! as! BalloonPopupCell
                cell.decorateView()
                cell.hideSeparator()
                return cell
            }
            
            if indexPath == rateIndex {
                let cell = tableView.dequeueReusableCell(withIdentifier: "rate")! as! BalloonPopupCell
                cell.decorateView()
                cell.hideSeparator()
                return cell
            }
            
            if index == (classes?.count ?? 0) + classOffsetCount {
                let cell = tableView.dequeueReusableCell(withIdentifier: "subtitle") as! TitleCell
                cell.decorate("View all classes")
                cell.hideSeparator()
                return cell
            }
            
            if let classes = classes {
                let displayClass = classes[index - classOffsetCount]
                let cell = tableView.dequeueReusableCell(withIdentifier: "classWithIcon") as! ClassNameCell
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
                let cell = tableView.dequeueReusableCell(withIdentifier: "titleWithButton") as! TitleWithButtonCell
                cell.decorate("Recent Announcements", buttonText: "mark all read", activityIndicatorHidden: !self.loadingAnnouncements)
                recentAnnouncementsCell = cell
                
                //only show button if there is an unread announcement
                cell.button.isHidden = true
                for ann in self.announcements {
                    if !ann.hasBeenRead() {
                        recentAnnouncementsCell?.button?.isHidden = false
                        break
                    }
                }
                return cell
            }
            if index == 1 && announcements.count == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "message") as! TitleCell
                cell.decorate(loadingAnnouncements ? "Loading Announcements..." : "No announcements posted.")
                return cell
            }
            let announcement = announcements[index - announcementIndexOffset]
            let cell = tableView.dequeueReusableCell(withIdentifier: "announcement") as! AnnouncementCell
            cell.decorate(announcement)
            return cell
        }
        
        return tableView.dequeueReusableCell(withIdentifier: "classWithIcon")!
    }
    
    func reloadTable() {
        if tableView == nil { return }
        
        self.tableView.reloadData()
        updateBottomView()
    }
    
    
    //MARK: - Handle announcements as they're loaded
    
    func loadAnnouncements(reloadClasses: Bool = true, withInlineActivityIndicator: Bool = false) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: TSPerformingNetworkActivityNotification), object: true, userInfo: nil)
        if reloadClasses { self.classes = TSAuthenticatedReader.getActiveClasses() }
        
        self.loadingAnnouncements = true
        
        //reload the Recent Announcements Cell to get enable the activity indicator
        if withInlineActivityIndicator {
            tableView.reloadRows(at: [IndexPath(item: 0, section: 1)], with: .none)
        }
        
        self.announcements = []
        
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
            TSNetworkQueue.async {
                let announcements = TSAuthenticatedReader.getAnnouncementsForClass(currentClass)
                
                func markLoadedAndCheckIfDone() -> Bool {
                    doneLoadingCount += 1
                    return doneLoadingCount == necessaryCount
                }
                
                self.addAnnouncements(announcements)
                if markLoadedAndCheckIfDone() {
                    DispatchQueue.main.sync { self.doneLoadingAnnoucements() }
                }
            }
        }
        
    }
    
    func addAnnouncements(_ newAnnouncements: [Announcement]) {
        
        for ann in newAnnouncements {
            announcements.append(ann)
        }
        
        //resort
        announcements.sort(by: { ann1, ann2 in
            if let date1 = ann1.date, let date2 = ann2.date {
                return date1.timeIntervalSince(date2 as Date) > 0
            }
            return false
        })
        
        //trim to most recent
        let recentCount = iPad() ? 10 : 5
        
        if announcements.count > recentCount {
            if let first = announcements.indices.first, let last = announcements.indices.last {
                if let begin = announcements.index(first, offsetBy: recentCount, limitedBy: (announcements.count - 1)) {
                    announcements.removeSubrange(begin ... last)
                }
            }
        }
    }
    
    func doneLoadingAnnoucements() {
        if !loadingAnnouncements {
            return
        }
        loadingAnnouncements = false
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: TSPerformingNetworkActivityNotification), object: false)
        
        if announcements.count == 0 { self.reloadTable() }
        
        //animate the announcements
        //don't animate if this delegate isn't visible anymore
        if delegateStack.count != 0 { return }
        
        tableView.beginUpdates()
        
        //reload the Recent Announcements Cell to get rid of the activity indicator
        tableView.reloadRows(at: [IndexPath(item: 0, section: 1)], with: .none)
        
        if announcements.count != 0 {
            //remove "Loading Announcements..."
            tableView.deleteRows(at: [IndexPath(item: 1, section: 1)], with: UITableViewRowAnimation.left)
        }
        
        //animate
        let recentCount = iPad() ? 10 : 5
        let previous: [Announcement] = []
        
        for i in 0 ..< recentCount {
            if previous.count > i && !(announcements as NSArray).contains(previous[i]) { //will never be called with the current setup
                tableView.deleteRows(at: [IndexPath(item: i + 1, section: 1)], with: UITableViewRowAnimation.top)
            }
            
            if announcements.count > i && !(previous as NSArray).contains(announcements[i]) {
                tableView.insertRows(at: [IndexPath(item: i + 1, section: 1)], with:  UITableViewRowAnimation.fade)
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
    }
    
    
    //MARK: - Customization of the view
    
    override func viewDidLoad() {
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(ClassesViewController.tableRefreshed(_:)), for: .valueChanged)
        tableView.addSubview(refreshControl)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 30.0, right: 0.0)
        tableView.tableFooterView = UIView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        tableViewRestingPosition = tableView.frame.origin
        updateBottomView()
        NotificationCenter.default.addObserver(self, selector: #selector(ClassesViewController.setTouchDelegateEnabled(_:)), name: NSNotification.Name(rawValue: TSSetTouchDelegateEnabledNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ClassesViewController.backTriggeredFromButtonPress), name: NSNotification.Name(rawValue: TSBackPressedNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ClassesViewController.scrollToTop), name: NSNotification.Name(rawValue: TSStatusBarTappedNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ClassesViewController.pushSettingsDelegate), name: NSNotification.Name(rawValue: TSShowSettingsNotification), object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateBottomView()
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: TSSetTouchDelegateEnabledNotification), object: false)
        delay(0.5) {
            NotificationCenter.default.post(name: Notification.Name(rawValue: TSSetTouchDelegateEnabledNotification), object: true)
        }
    }
    
    func updateBottomView(offset: CGFloat = 0) {
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
            UIView.animate(withDuration: 0.35, animations: {
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
    
    @IBAction func viewPanned(_ sender: UIPanGestureRecognizer) {
        //do nothing for vertical scrolling until panning actually starts
        if !panning {
            let velocity = sender.velocity(in: self.tableView)
            if 2 * abs(velocity.y) > abs(velocity.x) { return }
        }
        
        if sender.state == .began {
            
            //don't start a pan if this touch is ignored by the delegate
            let touch = sender.location(in: tableView)
            if let indexPath = tableView.indexPathForRow(at: touch),
               let cell = tableView.cellForRow(at: indexPath) {
                
                if (tableView.delegate as? StackableTableDelegate)?.shouldIgnoreTouch?(touch, inCell: cell) == true {
                    return
                }
            }
            
            panning = true
            NotificationCenter.default.post(name: Notification.Name(rawValue: TSSetTouchDelegateEnabledNotification), object: false)
            tableViewRestingPosition = tableView.frame.origin
        }
        
        if !panning { return }
        
        if sender.state == .ended {
            NotificationCenter.default.post(name: Notification.Name(rawValue: TSSetTouchDelegateEnabledNotification), object: true)
            panning = false
        }
        
        if delegateStack.count == 0 {
            return
        }
        
        if sender.state == .ended {
            tableView.isScrollEnabled = true
            tableView.isUserInteractionEnabled = true
            
            let newTablePosition = tableViewRestingPosition
            let newBottomPosition = CGPoint(x: tableViewRestingPosition.x, y: bottomView.frame.origin.y)
            
            if sender.velocity(in: self.tableView).x <= 0 {
                //if they were swiping back towards the left, do nothing
                UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [], animations: {
                    self.tableView.frame.origin = newTablePosition!
                    self.bottomView.frame.origin = newBottomPosition
                }, completion: nil)
                return
            }
            
            let endPosition = self.tableView.frame.origin.x
            self.tableView.frame.origin = newTablePosition!
            self.bottomView.frame.origin = newBottomPosition
            
            if endPosition > tableViewRestingPosition.x + 10.0 {
                self.popDelegate()
            }
            else {
                self.unhighlightAllCells()
            }
            return
        }
        
        tableView.isScrollEnabled = false
        tableView.isUserInteractionEnabled = false
        let translation = sender.translation(in: self.view)
        self.tableView.frame.origin = CGPoint(x: max(tableViewRestingPosition.x, tableViewRestingPosition.x + translation.x), y: 0.0)
        self.bottomView.frame.origin = CGPoint(x: max(tableViewRestingPosition.x, tableViewRestingPosition.x + translation.x), y: bottomView.frame.origin.y)
    }
    
    @IBAction func touchDown(_ sender: UITapGestureRecognizer) {
        let touch = sender.location(in: tableView)
        self.processTouchInTableView(touch, state: sender.state)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func animateSelection(_ cell: UITableViewCell, indexPath: IndexPath, selected: Bool) {
        let background: UIColor
        
        if indexPath.section == 0 {
            if indexPath == backToGTPortalIndex {
                //R:0.08 G:0.24 B:0.45 A:0.85
                background = UIColor(red: 0.08, green: 0.24, blue: 0.45, alpha: selected ? 0.6 : 0.85)
            }
            else {
                if indexPath.item == (backToGTPortalIndex == nil ? 0 : 1) { return }
                background = UIColor(white: 1.0, alpha: selected ? 0.3 : 0.0)
            }
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
        
        UIView.animate(withDuration: 0.3, animations: {
            cell.backgroundColor = background
        })
    }
    
    func setTouchDelegateEnabled(_ notification: Notification) {
        if let enabled = notification.object as? Bool {
            touchRecognizer.isEnabled = enabled
            
            if !enabled {
                for cell in tableView.visibleCells {
                    let index = tableView.indexPath(for: cell)!
                    if let delegate = tableView.delegate as? StackableTableDelegate, delegate.canHighlightCell(index) == true {
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
        backTriggered()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        delay(0.01) {
            self.reloadTable()
        }
    }
    
    func tableRefreshed(_ refresh: UIRefreshControl) {
        guard let delegate = tableView.delegate as? StackableTableDelegate else {
            refresh.endRefreshing()
            return
        }
        
        TSNetworkQueue.async {
            delegate.loadData()
            sync {
                self.reloadTable()
                refresh.endRefreshing()
            }
        }
        
    }
    
    func scrollToTop() {
        tableView.setContentOffset(CGPoint.zero, animated: true)
    }
    
    //MARK: - Stackable Table Delegate methods
    
    func processSelectedCell(_ index: IndexPath) {
        print("SHOULD NOT BE CALLED")
        return //unused in favor of processSelectedCellWithTouch
    }
    
    func processSelectedCellWithTouch(_ index: IndexPath, _ touchLocationInCell: CGPoint) {
        if index.section == 0 {
            if index == backToGTPortalIndex {
                UIApplication.shared.openURL(URL(string: "gtportal://")!)
                return
            }
            if index.item == (backToGTPortalIndex == nil ? 0 : 1) { return }
            if index.item == (classes?.count ?? 0) + classOffsetCount {
                let delegate = AllClassesDelegate(controller: self)
                delegate.loadDataAndPushInController(self)
                return
            }
            
            //"That's a lot of classes" popup
            if index == tooManyClassesIndex {
                if let cell = tableView.cellForRow(at: index) as? BalloonPopupCell {
                    let action = cell.actionForTouch(touchLocationInCell)
                    
                    if action == .action {
                        let delegate = AllClassesDelegate(controller: self)
                        delegate.loadDataAndPushInController(self)
                        return
                    }
                        
                    else if action == .cancel {
                        //remove cell
                        self.tableView.beginUpdates()
                        
                        let oldIndex = tooManyClassesIndex!
                        tooManyClassesIndex = nil
                        self.alertHidden = true
                        UserDefaults.standard.set(true, forKey: TSHideClassCountPopupKey)
                        
                        tableView.deleteRows(at: [oldIndex], with: .fade)
                        self.tableView.endUpdates()
                    }
                }
                return
            }
            
            //rate popup
            if index == rateIndex {
                if let cell = tableView.cellForRow(at: index) as? BalloonPopupCell {
                    let action = cell.actionForTouch(touchLocationInCell)
                    
                    if action == .action {
                        let link = "itms-apps://itunes.apple.com/us/app/t-squared-for-georgia-tech/id1046350734"
                        UIApplication.shared.openURL(URL(string: link)!)
                        
                        UserDefaults.standard.set(true, forKey: TSNeverShowRateAlertKey)
                        
                        delay(0.5) {
                            self.rateIndex = nil
                            self.reloadTable()
                        }
                    }
                    
                    else if action == .cancel {
                        let oldIndex = self.rateIndex!
                        
                        //remove cell
                        self.tableView.beginUpdates()
                        self.alertHidden = true
                        self.rateIndex = nil
                        
                        //if this isn't the first time seeing this alert, never show it again
                        if UserDefaults.standard.integer(forKey: TSLoginCountKey) > 20 {
                            UserDefaults.standard.set(true, forKey: TSNeverShowRateAlertKey)
                        }
                        
                        self.tableView.deleteRows(at: [oldIndex], with: .left)
                        self.tableView.endUpdates()
                        
                        //offset bottom view by height of alert
                        updateBottomView(offset: CGFloat(100.0))
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
    
    func usesBottomView(_ delegate: AnyObject) -> Bool {
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
    
    func pushDelegate(_ delegate: StackableTableDelegate, ifCurrentMatchesExpected expected: UITableViewDelegate) {
        if expected === tableView.delegate {
            pushDelegate(delegate)
        }
    }
    
    fileprivate func pushDelegate(_ delegate: StackableTableDelegate) {
        pushDelegate(delegate, hasBeenUpdatedToNewLoadFormat: true)
    }
    
    override func pushDelegate(_ delegate: StackableTableDelegate, hasBeenUpdatedToNewLoadFormat: Bool) {
        if DISABLE_PUSHES { return }
        
        bottomView.isHidden = !(usesBottomView(delegate))
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
        bottomView.isHidden = !(usesBottomView(delegate))
        updateBottomView()
        let timingFunction = CAMediaTimingFunction(controlPoints: 0.215, 0.61, 0.355, 1)
        playTransitionForView(bottomView, duration: 0.4, transition: kCATransitionPush, subtype: kCATransitionFromLeft, timingFunction: timingFunction)
    }
    
    func canHighlightCell(_ index: IndexPath) -> Bool {
        return index != IndexPath(item: 0, section: 1)
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
        recentAnnouncementsCell?.button?.isHidden = true
    }
    
    func presentDocumentFromURL(_ webURL: URL, name: String = "Attachment") {
        self.setActivityIndicatorVisible(true)
        
        //open a .url or .webloc file in a browser instead of trying to download it
        let url = webURL.absoluteString.lowercased()
        if url.hasSuffix(".url") == true || url.hasSuffix(".webloc") == true {
            self.openLinkInWebView(webURL.absoluteString, title: name)
            return
        }
        
        TSNetworkQueue.async(execute: {
            guard let data = try? Data(contentsOf: webURL) else {
                sync {
                    let alert = UIAlertController(title: "Cannot Display Attachment", message: "The attachment is no longer available.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    self.setActivityIndicatorVisible(false)
                }
                return
            }
            
            //get the URL's file extension
            let splits = webURL.path.components(separatedBy: ".")
            let fileType = splits.last!
            
            //get URL to save to
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            let documents = paths[0] as NSString
            let fileURLpath = documents.appendingPathComponent("\(name).\(fileType)")
            try? data.write(to: URL(fileURLWithPath: fileURLpath), options: [])
            let fileURL = URL(fileURLWithPath: fileURLpath)
            
            sync() {
                let controller = UIDocumentInteractionController(url: fileURL)
                self.documentController = controller
                controller.delegate = self
                
                let success = controller.presentPreview(animated: true)
                
                if (success) {
                    delay(0.5) {
                        self.setActivityIndicatorVisible(false)
                    }
                } else {
                    self.openLinkInWebView(webURL.absoluteString, title: name)
                }
                
            }
                
        })
    }
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    func openFromLinks(_ links: [String]) {
        
        func shortSiteForLink(_ link: String) -> String {
            let shortWebsite = websiteForLink(link)
            //handle duplicates
            var countMatching = 0
            var thisCount = 1
            for other in links {
                let otherShort = websiteForLink(other)
                if otherShort == shortWebsite {
                    countMatching += 1
                }
                if other == link {
                    thisCount = countMatching
                }
            }
            
            return shortWebsite + (countMatching > 1 ? "\(thisCount)" : "")
        }
        
        if links.count == 0 { return }
        if links.count == 1 {
            let alert = UIAlertController(title: "Open link?", message: websiteForLink(links[0]), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: nil))
            alert.addAction(UIAlertAction(title: "Open", style: .default, handler: { _ in
                self.openLinkInWebView(links[0], title: websiteForLink(links[0]))
            }))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        let alert = UIAlertController(title: "Open link?", message: "There are multiple links in this message. Which would you like to open?", preferredStyle: .alert)
        for link in links {
            alert.addAction(UIAlertAction(title: shortSiteForLink(link), style: .default, handler: { _ in
                self.openLinkInWebView(link, title: websiteForLink(link))
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func openLinkInWebView(_ link: String, title: String) {
        guard let URL = URL(string: link) else {
            let alert = UIAlertController(title: "Could not open link.", message: "We had a problem opening that link. (\(link))", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "ok", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        loginController.presentWebViewWithURL(URL, title: title)
    }
    
    func openTextInWebView(_ text: String, title: String) {
        loginController.presentWebViewWithText(text, title: title)
    }
    
    func setActivityIndicatorVisible(_ visible: Bool) {
        let scale: CGFloat = visible ? 1.0 : 0.1
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        
        UIView.animate(withDuration: visible ? 0.7 : 0.4, delay: 0.0, usingSpringWithDamping: visible ? 0.5 : 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.loginController.activityCircle.transform = transform
            self.loginController.activityCircle.alpha = visible ? 1.0 : 0.0
        }, completion: nil)
    }
    
    func pushSettingsDelegate() {
        pushDelegate(SettingsDelegate(controller: self), hasBeenUpdatedToNewLoadFormat: true)
    }
    
    func openContactEmail() {
        if !MFMailComposeViewController.canSendMail() {
            let alert = UIAlertController(title: "Cannot Send Mail", message: "You mail account is not set up correctly.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        let mail = MFMailComposeViewController()
        mail.setToRecipients(["cal@calstephens.tech"])
        mail.setSubject("T-Squared Support for Version \(Bundle.applicationVersionNumber) (\(Bundle.applicationBuildNumber))")
        mail.mailComposeDelegate = self
        self.present(mail, animated: true, completion: nil)
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    
}

extension StackableTableDelegate {
    
    var indexPathsForHeader: [IndexPath] {
        return [IndexPath(item: 0, section: 0)]
    }
    
    func loadDataAndPushInController(_ controller: ClassesViewController) {
        let previousDelegate: UITableViewDelegate! = controller.tableView.delegate
        
        let firstLoad = isFirstLoad()
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        if (firstLoad) {
            controller.setActivityIndicatorVisible(true)
        }
        
        if !firstLoad {
            self.loadCachedData()
            controller.pushDelegate(self)
            NotificationCenter.default.post(name: Notification.Name(rawValue: TSPerformingNetworkActivityNotification), object: true)
        }
        
        TSNetworkQueue.async(execute: {
            self.loadData()
            
            sync {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                if controller.activityIndicator.alpha == 1.0 && !(self is AnnouncementDelegate) {
                    controller.setActivityIndicatorVisible(false)
                }
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: TSPerformingNetworkActivityNotification), object: false)
                
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
    
    func reloadDataIfNecessary(_ controller: ClassesViewController) {
        if isFirstLoad() {
            print("RELOADING DATA for the popped delegate. Something went missing.")
            
            controller.setActivityIndicatorVisible(true)
            TSNetworkQueue.async {
                self.loadData()
                sync() {
                    controller.reloadTable()
                    controller.setActivityIndicatorVisible(false)
                }
            }
            
        }
    }
    
}
