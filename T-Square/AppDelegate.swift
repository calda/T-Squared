//
//  AppDelegate.swift
//  T-Square
//
//  Created by Cal on 8/26/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
        
        //TODO: Move this to after a successful login
        let types: UIUserNotificationType = [.Alert, .Sound, .Badge]
        UIApplication.sharedApplication().registerUserNotificationSettings(UIUserNotificationSettings(forTypes: types, categories: nil))
    
        return true
    }
    
    func application(application: UIApplication, performFetchWithCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        print("LOADING NEW DATA")
        fireNotification(application, message: "Loading T-Square Data", delay: 0.0)
        completionHandler(UIBackgroundFetchResult.NewData)
    }
    
    func fireNotification(application: UIApplication, message: String, delay: NSTimeInterval) {
        print("fired notification")
        let notification = UILocalNotification()
        notification.fireDate = NSDate(timeIntervalSinceNow: delay)
        notification.alertBody = message
        notification.alertAction = "View"
        notification.soundName = UILocalNotificationDefaultSoundName
        notification.hasAction = true
        notification.timeZone = NSTimeZone.defaultTimeZone()
        application.scheduleLocalNotification(notification)
    }
    
    func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
        print(notification.alertBody!)
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

