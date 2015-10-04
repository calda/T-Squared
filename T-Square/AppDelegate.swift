//
//  AppDelegate.swift
//  T-Square
//
//  Created by Cal on 8/26/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import UIKit

let TSStatusBarTappedNotification = "edu.gatech.cal.statusBarTapped"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        return true
    }

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

    func applicationDidBecomeActive(application: UIApplication) {
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
        }
    }
    
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
