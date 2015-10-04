//
//  AppDelegate.swift
//  T-Square
//
//  Created by Cal on 8/26/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import UIKit

let TSReturnFromBackgroundNotification = "edu.gatech.cal.returnFromBackground"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        
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

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
    
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

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

}
