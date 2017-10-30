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
var TSLaunchedUsername: String?
var TSWasLaunchedFromGTPortal = false

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    
    //MARK: - Launch from URL
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.networkActivityEvent(_:)), name: NSNotification.Name(rawValue: TSPerformingNetworkActivityNotification), object: nil)
        
        if let launchSource = launchOptions?[UIApplicationLaunchOptionsKey.sourceApplication] as? String,
           let launchURL = launchOptions?[UIApplicationLaunchOptionsKey.url] as? URL {
            self.application(UIApplication.shared, open: launchURL, sourceApplication: launchSource, annotation: "")
        }
        
        return true
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        
        if sourceApplication == "CBTech.GT" && ProcessInfo().operatingSystemVersion.majorVersion < 9 {
            TSWasLaunchedFromGTPortal = true
            let controller = (window?.rootViewController as? LoginViewController)?.classesViewController
            controller?.reloadTable()
            if controller?.tableView?.delegate is ClassesViewController {
                controller?.tableView.contentOffset = CGPoint(x: 0.0, y: 0.0)
            }
        }
        
        //check for launch from tsquared:// url
        TSLaunchedUsername = "\(url)".replacingOccurrences(of: "tsquared://", with: "")
        if TSLaunchedUsername == "" { TSLaunchedUsername = nil }
        return true
    }
    
    
    //MARK: Tracking Network Activity
    var networkActivityCount = 0
    
    func networkActivityEvent(_ notification: Notification) {
        
        let activityToggle: Bool
        
        if let notificationBool = notification.object as? Bool {
            activityToggle = notificationBool
        } else if let notificationInt = notification.object as? Int {
            activityToggle = (notificationInt == 1 ? true : false)
        } else {
            return
        }
        
        //update count
        networkActivityCount += activityToggle ? 1 : -1
        networkActivityCount = max(0, networkActivityCount)
        
        let notificationBool: Bool?
        if networkActivityCount == 0 { notificationBool = false }
        else if networkActivityCount == 1 { notificationBool = true }
        else { notificationBool = nil }
        
        if let notificationBool = notificationBool {
            NotificationCenter.default.post(name: Notification.Name(rawValue: TSSetActivityIndicatorEnabledNotification), object: notificationBool, userInfo: nil)
        }

    }
    
    
    //MARK: Disable selection for cells when the app resigns active
    //like when a notification is tapped on
    
    func applicationWillResignActive(_ application: UIApplication) {
        
        if TSAuthenticatedReader == nil { return }
        
        //disable selection for all cells
        if let loginController = window?.rootViewController as? LoginViewController {
            let tableView = loginController.classesViewController.tableView
            if let delegate = tableView?.delegate as? StackableTableDelegate {
                for cell in (tableView?.visibleCells)! {
                    if let indexPath = tableView?.indexPath(for: cell) {
                        delegate.animateSelection(cell, indexPath: indexPath, selected: false)
                    }
                }
            }
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        TSWasLaunchedFromGTPortal = false
        (window?.rootViewController as? LoginViewController)?.classesViewController?.reloadTable()
    }
    
    
    //MARK: Open from Springboard 3D Touch shortcut
    
    func openShortcutItemIfPresent() {
        if #available(iOS 9.0, *) {
            guard let item = TSQueuedShortcutItem else { return }
            TSQueuedShortcutItem = nil
            
            guard let info = item.userInfo else { return }
            guard let URL = info["URL"] as? String else { return }
            guard let fullName = info["FULL_NAME"] as? String else { return }
            guard let displayName = info["DISPLAY_NAME"] as? String else { return }
            let openedClass = Class(withFullName: fullName, link: URL, displayName: displayName)
            
            print("Opening \(openedClass.name) from Shortcut Item")
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
            let stackItem: (delegate: StackableTableDelegate, contentOffset: CGPoint) = (classesController, CGPoint(x: 0.0, y: 0.0))
            classesController.delegateStack.push(stackItem)
            
            networkActivityCount = 0 //reset counter
            
            loginController.animatePresentClassesView()
        }
    }
    
    @available(iOS 9.0, *)
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        
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
            
            if TSAuthenticatedReader != nil {
                openShortcutItemIfPresent()
            }
        }
    }
    
    
    //MARK: Check if a touch happens in the status bar
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let window = self.window else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: window)
        let statusBarFrame = UIApplication.shared.statusBarFrame
        if statusBarFrame.contains(location) {
            postNotification(TSStatusBarTappedNotification, object: nil)
        }
    }

}
