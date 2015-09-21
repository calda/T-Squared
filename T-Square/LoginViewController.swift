//
//  ViewController.swift
//  T-Square
//
//  Created by Cal on 8/26/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import UIKit
import Foundation

let TSUsernamePath = "edu.gatech.cal.username"
let TSPasswordPath = "edu.gatech.cal.password"
var TSAuthenticatedReader: TSReader!
let TSLogoutNotification = "edu.gatech.cal.logout"

class LoginViewController: UIViewController {

    @IBOutlet weak var formCenter: NSLayoutConstraint!
    @IBOutlet weak var backgroundBottom: NSLayoutConstraint!
    @IBOutlet weak var formBlurView: UIVisualEffectView!
    @IBOutlet weak var formView: UIView!
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var loggingInText: UILabel!
    var originalLoggingInText: NSAttributedString!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var saveCredentialsSwitch: UISwitch!
    @IBOutlet weak var containerLeading: NSLayoutConstraint!
    @IBOutlet var tapRecognizer: UITapGestureRecognizer!
    
    var classesViewController: ClassesViewController!
    
    //MARK: - Preparing the View Controller
    override func viewWillAppear(animated: Bool) {
        if animated { return }
        
        self.formCenter.constant = self.view.frame.height / 2.0
        self.containerLeading.constant = UIScreen.mainScreen().bounds.width
        self.view.layoutIfNeeded()
        
        originalLoggingInText = loggingInText.attributedText!
        
        let data = NSUserDefaults.standardUserDefaults()
        if let savedUsername = data.stringForKey(TSUsernamePath), let savedPassword = data.stringForKey(TSPasswordPath) {
            animateFormSubviewsWithDuration(0.0, hidden: true)
            usernameField.text = savedUsername
            passwordField.text = savedPassword
            doLogin(newLogin: false)
        }
        
        UIView.animateWithDuration(0.7, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [], animations: {
            self.formCenter.constant = 10.0
            self.view.layoutIfNeeded()
        }, completion: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "logout", name: TSLogoutNotification, object: nil)
        
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let classes = segue.destinationViewController as? ClassesViewController {
            classesViewController = classes
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardHeightChanged:", name: UIKeyboardWillChangeFrameNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "centerForm", name: UIKeyboardWillHideNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "networkErrorRecieved", name: TSNetworkErrorNotification, object: nil)
    }
    
    //MARK: - Animating and processing form input
    
    func keyboardHeightChanged(notification: NSNotification) {
        if let userInfo = notification.userInfo,
           let keyboardFrame = (userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue {
            
            let keyboardHeight = keyboardFrame().height
            let newConstant = -10 - (keyboardHeight / (is4S() ? 2.5 : 3.0))
            
            if newConstant == formCenter.constant { return }
            
            UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
                self.formCenter.constant = newConstant
                self.backgroundBottom.constant = keyboardHeight - 100.0
                self.view.layoutIfNeeded()
            }, completion: nil)
            
        }
    }
    
    func centerForm() {
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.formCenter.constant = -10.0
            self.backgroundBottom.constant = 0.0
            self.view.layoutIfNeeded()
            }, completion: nil)
    }

    @IBAction func switchToPasswordInput(sender: AnyObject) {
        passwordField.becomeFirstResponder()
    }
    
    @IBAction func loginPressed(sender: AnyObject) {
        doLogin(newLogin: true)
    }
    
    func doLogin(newLogin newLogin: Bool) {
        if usernameField.text! == "" || passwordField.text! == "" {
            shakeView(formView)
            return
        }
        
        //center the form
        self.passwordField.resignFirstResponder()
        self.usernameField.resignFirstResponder()
        centerForm()
        
        //easter-egg
        if self.usernameField.text! == "gburdell1927" {
            self.passwordField.text = ""
            let alert = UIAlertController(title: "Nice Try, you trickster", message: "George Burdell, is that you???", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "You found me out", style: .Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
            return
        }
        
        //animate the activity indicator
        animateFormSubviewsWithDuration(0.5, hidden: true)
        animateActivityIndicator(on: true)
        
        //attempt to authenticate
        dispatch_async(TSNetworkQueue, {
            TSReader.authenticatedReader(user: self.usernameField.text!, password: self.passwordField.text!, isNewLogin: newLogin, completion: { reader in
                
                if let reader = reader {
                    TSAuthenticatedReader = reader
                    self.animateFormSubviewsWithDuration(0.5, hidden: false)
                    self.animateActivityIndicator(on: false)
                    self.setSavedCredentials(correct: true)
                    self.presentClassesView(reader)
                }
                
                else {
                    self.passwordField.text = ""
                    shakeView(self.formView)
                    self.animateFormSubviewsWithDuration(0.5, hidden: false)
                    self.animateActivityIndicator(on: false)
                    self.setSavedCredentials(correct: false)
                }
                
            })
        })
        
    }
    
    func networkErrorRecieved() {
        sync {
            self.animateFormSubviewsWithDuration(0.5, hidden: false)
            self.animateActivityIndicator(on: false)
            
            let alert = UIAlertController(title: "Couldn't connect to T-Square", message: "Are you connected to the internet?", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .Destructive, handler: nil))
            alert.addAction(UIAlertAction(title: "Settings", style: .Default, handler: { _ in openSettings() }))
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    func setSavedCredentials(correct correct: Bool) {
        let save = correct && saveCredentialsSwitch.on
        let data = NSUserDefaults.standardUserDefaults()
        data.setValue(save ? usernameField.text! : nil, forKey: TSUsernamePath)
        data.setValue(save ? passwordField.text! : nil, forKey: TSPasswordPath)
    }
    
    func animateFormSubviewsWithDuration(duration: Double, hidden: Bool) {
        for subview in formView.subviews {
            if !(subview is UIVisualEffectView) && subview.tag != -1 {
                UIView.animateWithDuration(duration) {
                    subview.alpha = hidden ? 0.0 : (subview.tag == 1 ? 0.3 : 1.0)
                }
            }
        }
        UIView.animateWithDuration(duration) {
            self.loggingInText.alpha = hidden ? 1.0 : 0.0
        }
        let loggingInString = originalLoggingInText.mutableCopy() as! NSMutableAttributedString
        loggingInString.replaceCharactersInRange(NSMakeRange(14, 8), withString: usernameField.text!)
        self.loggingInText.attributedText = loggingInString
    }
    
    func animateActivityIndicator(on on: Bool) {
        
        var originalIndicatorPosition: CGPoint {
            return CGPointMake(CGRectGetMidX(formView.frame) - activityIndicator.frame.width / 2.0, (CGRectGetMidY(formView.frame) - activityIndicator.frame.height / 2.0) + 20.0)
        }
        
        if on {
            let originalPosition = originalIndicatorPosition
            let animationStart = CGPointMake(originalPosition.x, originalPosition.y + 50)
            activityIndicator.frame.origin = animationStart
            UIView.animateWithDuration(0.7, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [], animations: {
                self.activityIndicator.frame.origin = originalPosition
                self.activityIndicator.alpha = 1.0
            }, completion: nil)
        }
        else {
            let originalPosition = originalIndicatorPosition
            let animationEnd = CGPointMake(originalPosition.x, originalPosition.y + 50)
            UIView.animateWithDuration(0.7, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [], animations: {
                self.activityIndicator.frame.origin = animationEnd
                self.activityIndicator.alpha = 0.0
            }, completion: nil)
        }
    }
    
    @IBAction func defocusTextViews(sender: UITapGestureRecognizer) {
        let touch = sender.locationInView(self.view)
        let blurFrame = self.view.convertRect(formBlurView.frame, fromView: formBlurView.superview!)
        if !CGRectContainsPoint(blurFrame, touch) {
            usernameField.resignFirstResponder()
            passwordField.resignFirstResponder()
            centerForm()
        }
    }
    
    //MARK: - Switching Views
    
    func presentClassesView(reader: TSReader) {
        tapRecognizer.enabled = false
        var classes: [Class] = []
        var loadAttempt = 0
        while classes.count == 0 && loadAttempt < 10 {
            loadAttempt++
            classes = reader.getClasses()
        }
        
        if loadAttempt >= 10 {
            //present an alert and then exit the app if the classes aren't loading
            //this means a failed authentication looked like it passed
            //AKA I have no idea what happened
            let alert = UIAlertController(title: "There was a problem logging you in.", message: "This happens every now and then. Please restart T-Squared and try again.", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Restart", style: .Default, handler: { _ in
                HttpClient.sendLogoutRequest()
            }))
            self.presentViewController(alert, animated: true, completion: nil)
            self.setSavedCredentials(correct: false)
            return
        }
        
        classesViewController.classes = classes
        classesViewController.reloadTable()
        
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.formView.alpha = 0.0
            self.formView.transform = CGAffineTransformMakeScale(0.6, 0.6)
            self.containerLeading.constant = 0.0
            self.view.layoutIfNeeded()
        }, completion: nil)
        
        dispatch_async(TSNetworkQueue, {
            for currentClass in classes {
                let announcements = reader.getAnnouncementsForClass(currentClass)
                sync() {
                    self.classesViewController.addAnnouncements(announcements)
                }
            }
            sync() { self.classesViewController.doneLoadingAnnoucements() }
        })
    }
    
    //logout from gatech login service and trash saved passwords
    func logout() {
        self.classesViewController.announcements = []
        self.classesViewController.classes = nil
        NSURLCache.sharedURLCache().removeAllCachedResponses()
        let cookies = NSHTTPCookieStorage.sharedHTTPCookieStorage()
        for cookie in (cookies.cookies ?? []) {
            cookies.deleteCookie(cookie)
        }
        
        HttpClient.sessionID = nil
        HttpClient.authFormPost = nil
        HttpClient.authLTPost = nil
        TSAuthenticatedReader = nil
        
        self.usernameField.text = ""
        self.passwordField.text = ""    
        self.setSavedCredentials(correct: false)
        
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.formView.alpha = 1.0
            self.formView.transform = CGAffineTransformMakeScale(1.0, 1.0)
            self.containerLeading.constant = self.view.frame.width
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        if self.containerLeading.constant == 0 { return }
        delay(0.01) {
            self.containerLeading.constant = self.view.frame.width
            self.view.layoutIfNeeded()
        }
    }
    
    
}

