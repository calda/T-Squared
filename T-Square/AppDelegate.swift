//
//  AppDelegate.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 8/26/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import UIKit

let TSStatusBarTappedNotification = "edu.gatech.cal.statusBarTapped"

@available(iOS 9.0, *)
var TSQueuedShortcutItem: UIApplicationShortcutItem?

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    //MARK: Tracking Network Activity

    var networkActivityCount = 0
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "networkActivityEvent:", name: TSPerformingNetworkActivityNotification, object: nil)
        return true
    }
    
    func networkActivityEvent(notification: NSNotification) {
        guard let activityToggle = notification.object as? Bool else { return }
        
        //update count
        networkActivityCount += activityToggle ? 1 : -1
        networkActivityCount = max(0, networkActivityCount)
        
        let notificationBool: Bool?
        if networkActivityCount == 0 { notificationBool = false }
        else if networkActivityCount == 1 { notificationBool = true }
        else { notificationBool = nil }
        
        if let notificationBool = notificationBool {
            NSNotificationCenter.defaultCenter().postNotificationName(TSSetActivityIndicatorEnabledNotification, object: notificationBool, userInfo: nil)
        }

    }
    
    //MARK: Disable selection for cells when the app resigns active
    //like when a notification is tapped on
    
    func applicationWillResignActive(application: UIApplication) {
        
        if TSAuthenticatedReader == nil { return }
        
        //disable selection for all cells
        if let loginController = window?.rootViewController as? LoginViewController {
            let tableView = loginController.classesViewController.tableView
            if let delegate = tableView.delegate as? StackableTableDelegate {
                for cell in tableView.visibleCells {
                    if let indexPath = tableView.indexPathForCell(cell) {
                        delegate.animateSelection(cell, indexPath: indexPath, selected: false)
                    }
                }
            }
        }
    }
    
    //MARK: Make sure we have an active connection once the app is opened again
    
    func applicationDidBecomeActive(application: UIApplication) {
        
        //verify authentication
        delay(0.1) {
            guard let _ = TSAuthenticatedReader else { return }
            guard let loginController = self.window?.rootViewController as? LoginViewController else { return }
            
            print("Validating connection")
            let rootPage = "http://t-square.gatech.edu/portal/pda/"
            let pageContents = HttpClient.contentsOfPage(rootPage, postNotificationOnError: false)?.toHTML
            
            guard let contents = pageContents else {
                //"Network unavailable."
                let alert = UIAlertController(title: "Couldn't connect to T-Square", message: "Network connection is unavailable.", preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "Nevermind", style: .Destructive, handler: nil))
                alert.addAction(UIAlertAction(title: "Settings", style: .Default, handler: { _ in openSettings() }))
                loginController.presentViewController(alert, animated: true, completion: nil)
                return
            }
            
            if !contents.containsString("Log Out") {
                //"Cookies invalid. Attempting to reconnect.
                HttpClient.isRunningInBackground = true
                TSReader.authenticatedReader(user: TSAuthenticatedReader.username, password: TSAuthenticatedReader.password, isNewLogin: false, completion: { reader in
                    if let reader = reader {
                        TSAuthenticatedReader = reader
                        //Successfully reconnected to T-Square
                        self.openShortcutItemIfPresent()
                    }
                    else {
                        loginController.unpresentClassesView()
                        let alert = UIAlertController(title: "Couldn't connect to T-Square", message: "Your login credentials have changed since the last time you logged in.", preferredStyle: .Alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                        loginController.presentViewController(alert, animated: true, completion: nil)
                    }
                })
                HttpClient.isRunningInBackground = false
            }
            else {
                self.openShortcutItemIfPresent()
            }
        }
    }
    
    //MARK: Open from Springboard 3D Touch shortcut
    
    func openShortcutItemIfPresent() {
        if #available(iOS 9.0, *) {
            guard let item = TSQueuedShortcutItem else { return }
            TSQueuedShortcutItem = nil
            
            guard let info = item.userInfo else { return }
            guard let URL = info["URL"] as? String else { return }
            guard let ID = info["ID"] as? String else { return }
            let openedClass = Class(withID: ID, link: URL)
            
            print("Opening \(openedClass.ID) from Shortcut Item")
            guard let loginController = window?.rootViewController as? LoginViewController else { return }
            guard let classesController = loginController.classesViewController else { return }
            
            //do nothing if the open delegate matches this class
            if let currentDelegate = classesController.tableView.delegate as? ClassDelegate {
                if currentDelegate.displayClass.link == URL {
                    currentDelegate.loadData()
                    return
                }
            }
            
            let delegate = ClassDelegate(controller: classesController, displayClass: openedClass)
            delegate.loadDataAndPushInController(classesController)
            
            //build a manual delegate stack
            //so that the only item in the stack is the ClassesViewController
            classesController.delegateStack = Stack()
            let stackItem: (delegate: StackableTableDelegate, contentOffset: CGPoint) = (classesController, CGPointMake(0.0, 0.0))
            classesController.delegateStack.push(stackItem)
            
            loginController.animatePresentClassesView()
        }
    }
    
    @available(iOS 9.0, *)
    func application(application: UIApplication, performActionForShortcutItem shortcutItem: UIApplicationShortcutItem, completionHandler: (Bool) -> Void) {
        
        guard let info = shortcutItem.userInfo else { return }
        guard let URL = info["URL"] as? String else { return }
        TSQueuedShortcutItem = shortcutItem
        
        //hide classes view controller and web view if they are already visible
        if let loginController = window?.rootViewController as? LoginViewController {
            
            if let currentDelegate = loginController.classesViewController.tableView.delegate as? ClassDelegate {
                if currentDelegate.displayClass.link != URL {
                    loginController.unpresentClassesView(0.0)
                }
            }
            
            loginController.dismissWebView(0.0)
            loginController.animateFormSubviewsWithDuration(0.0, hidden: true)
            delay(0.2) { loginController.animateActivityIndicator(on: true) }
        }
    }
    
    //MARK: Check if a touch happens in the status bar
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        super.touchesBegan(touches, withEvent: event)
        guard let window = self.window else { return }
        guard let touch = touches.first else { return }
        let location = touch.locationInView(window)
        let statusBarFrame = UIApplication.sharedApplication().statusBarFrame
        if CGRectContainsPoint(statusBarFrame, location) {
            postNotification(TSStatusBarTappedNotification, object: nil)
        }
    }

}
