//
//  ViewController.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 8/26/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import UIKit
import Foundation

var TSAuthenticatedReader: TSReader!
let TSLogoutNotification = "edu.gatech.cal.logout"
let TSDismissWebViewNotification = "edu.gatech.cal.dismissWeb"

class LoginViewController: UIViewController, UIGestureRecognizerDelegate {

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
    @IBOutlet weak var webViewTop: NSLayoutConstraint!
    @IBOutlet var tapRecognizer: UITapGestureRecognizer!
    
    var classesViewController: ClassesViewController!
    var browserViewController: TSWebView!
    @IBOutlet var activityCircle: UIView!
    
    //MARK: - Preparing the View Controller
    
    override func viewDidLoad() {
        //transition from old password scheme
        let data = NSUserDefaults.standardUserDefaults()
        
        if let savedUsername = data.stringForKey("edu.gatech.cal.username"),
           let savedPassword = data.stringForKey("edu.gatech.cal.password") {
            saveCredentials(username: savedUsername, password: savedPassword)
        }
        
        //nil-out the current values and close up that hole
        data.setValue(nil, forKey: "edu.gatech.cal.username")
        data.setValue(nil, forKey: "edu.gatech.cal.password")
    }
    
    override func viewWillAppear(animated: Bool) {
        if animated { return }
        if TSAuthenticatedReader != nil { return } //we're already authenticated
        
        //double check we aren't already authenticated
        let rootPage = "http://t-square.gatech.edu/portal/pda/"
        let pageContents = HttpClient.contentsOfPage(rootPage, postNotificationOnError: false)?.toHTML
        var validConnection = true
        
        if let contents = pageContents {
            if contents.containsString("Log Out") {
                //we're still on a valid connection, but the authenticated reader doesn't exist
                //recreate the reader
                if let (username, password) = savedCredentials() {
                    TSAuthenticatedReader = TSReader(username: username, password: password, initialPage: nil)
                    return
                }
                else {
                    //the reader doesn't exist, but we don't have stored credentials
                    //clear cookies and then prompt for login again
                    HttpClient.clearCookies()
                }
            }
        } else {
            //there were no page contents, meaning the network is unavailable
            validConnection = false
            delay(0.5) { self.syncronizedNetworkErrorRecieved() }
        }
        
        self.formCenter.constant = self.view.frame.height / 2.0
        self.webViewTop.constant = UIScreen.mainScreen().bounds.height
        self.containerLeading.constant = UIScreen.mainScreen().bounds.width
        self.view.layoutIfNeeded()
        
        originalLoggingInText = loggingInText.attributedText!
        
        if let (savedUsername, savedPassword) = savedCredentials() {
            usernameField.text = savedUsername
            passwordField.text = savedPassword
            
            if validConnection {
                animateFormSubviewsWithDuration(0.0, hidden: true)
                animateActivityIndicator(on: true)
                doLogin(newLogin: false)
            }
        }
        
        UIView.animateWithDuration(0.7, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [], animations: {
            self.formCenter.constant = 10.0
            self.view.layoutIfNeeded()
        }, completion: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "showLogoutAlert", name: TSLogoutNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "dismissWebView", name: TSDismissWebViewNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardHeightChanged:", name: UIKeyboardWillChangeFrameNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "centerForm", name: UIKeyboardWillHideNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "networkErrorRecieved", name: TSNetworkErrorNotification, object: nil)
        
        activityCircle.hidden = false
        activityCircle.layer.cornerRadius = 25.0
        activityCircle.layer.masksToBounds = true
        activityCircle.transform = CGAffineTransformMakeScale(0.0, 0.0)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let classes = segue.destinationViewController as? ClassesViewController {
            classes.loginController = self
            classesViewController = classes
        }
        if let browser = segue.destinationViewController as? TSWebView {
            browser.loginController = self
            self.browserViewController = browser
        }
    }
    
    //MARK: - Animating and processing form input
    
    func keyboardHeightChanged(notification: NSNotification) {
        //ignore if the classes controller is visible
        if self.containerLeading.constant == 0.0 { return }
        
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
            self.animateFormSubviewsWithDuration(0.5, hidden: false)
            self.animateActivityIndicator(on: false)
            self.setSavedCredentials(correct: false)
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
        delay(0.2) { self.animateActivityIndicator(on: true) }
        
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
            self.syncronizedNetworkErrorRecieved()
        }
    }
    
    func syncronizedNetworkErrorRecieved() {
        self.animateFormSubviewsWithDuration(0.5, hidden: false)
        self.animateActivityIndicator(on: false)
        
        let existingUsername = self.usernameField.text
        let existingPassword = self.passwordField.text
        
        //prevent the username and password from being cleared out
        delay(0.5) {
            self.usernameField.text = existingUsername
            self.passwordField.text = existingPassword
        }
        
        let alert = UIAlertController(title: "Couldn't connect to T-Square", message: "Are you connected to the internet?", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .Destructive, handler: nil))
        alert.addAction(UIAlertAction(title: "Settings", style: .Default, handler: { _ in openSettings() }))
        self.presentViewController(alert, animated: true, completion: nil)
        
        self.classesViewController.DISABLE_PUSHES = true
    }
    
    func setSavedCredentials(correct correct: Bool) {
        if !correct || !saveCredentialsSwitch.on {
            saveCredentials(username: nil, password: nil)
        }
        else {
            saveCredentials(username: usernameField.text, password: passwordField.text)
        }
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
            return CGPointMake(CGRectGetMidX(formView.frame) - activityIndicator.frame.width / 2.0, (CGRectGetMidY(formView.frame) - activityIndicator.frame.height / 2.0) + 50.0)
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
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    //MARK: - Switching Views
    
    func presentClassesView(reader: TSReader) {
        tapRecognizer.enabled = false
        var classes: [Class] = []
        var loadAttempt = 0
        while classes.count == 0 && loadAttempt < 15 && !reader.actuallyHasNoClasses {
            loadAttempt++
            classes = reader.getClasses()
            
            if classes.count == 0 {
                reader.checkIfHasNoClasses()
            }
            
            if loadAttempt > 4 {
                HttpClient.clearCookies()
            }
        }
        
        if loadAttempt >= 15 {
            //present an alert and then exit the app if the classes aren't loading
            //this means a failed authentication looked like it passed
            //AKA I have no idea what happened
            let message = "This happens every now and then. Please restart T-Squared and try again. If this keeps happening, please send an email to cal@calstephens.tech"
            let alert = UIAlertController(title: "There was a problem logging you in.", message: message, preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Restart", style: .Default, handler: { _ in
                //crash
                let null: Int! = nil
                null.threeCharacterString()
            }))
            self.presentViewController(alert, animated: true, completion: nil)
            self.setSavedCredentials(correct: false)
            return
        }
        
        classesViewController.classes = classes
        classesViewController.reloadTable()
        
        //open to the shortcut item if there is one queued
        if let delegate = UIApplication.sharedApplication().delegate as? AppDelegate {
            delegate.openShortcutItemIfPresent()
        }
        
        animatePresentClassesView()
        classesViewController.loadAnnouncements()
    }
    
    func animatePresentClassesView() {
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.formView.alpha = 0.0
            self.formView.transform = CGAffineTransformMakeScale(0.6, 0.6)
            self.containerLeading.constant = 0.0
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    func unpresentClassesView() {
        unpresentClassesView(0.5)
    }
    
    func unpresentClassesView(duration: Double) {
        UIView.animateWithDuration(duration, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.formView.alpha = 1.0
            self.formView.transform = CGAffineTransformMakeScale(1.0, 1.0)
            self.containerLeading.constant = self.view.frame.width
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    //logout from gatech login service and trash saved passwords
    func showLogoutAlert() {
        let alert = UIAlertController(title: nil, message: "Are you sure you want to log out?", preferredStyle: .ActionSheet)
        alert.addAction(UIAlertAction(title: "Log out", style: .Destructive, handler: { _ in self.logout() }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func logout() {
        self.classesViewController.announcements = []
        self.classesViewController.classes = nil
        NSURLCache.sharedURLCache().removeAllCachedResponses()
        HttpClient.clearCookies()
        
        HttpClient.sessionID = nil
        HttpClient.authFormPost = nil
        HttpClient.authLTPost = nil
        TSAuthenticatedReader = nil
        
        self.usernameField.text = ""
        self.passwordField.text = ""    
        self.setSavedCredentials(correct: false)
        NSUserDefaults.standardUserDefaults().setValue(nil, forKey: TSClassOpenCountKey)
        Class.updateShortcutItems()
        
        unpresentClassesView()
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        if self.containerLeading.constant != 0 {
            delay(0.01) {
                self.containerLeading.constant = self.view.frame.width
                self.view.layoutIfNeeded()
            }
        }
        
        if self.webViewTop.constant != 0 {
            delay(0.01) {
                self.webViewTop.constant = self.view.frame.height
                self.view.layoutIfNeeded()
            }
        }
    }
    
    //MARK: - Methods that shouldn't be in this View Controller
    
    var webViewVisible = false
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return webViewVisible ? .LightContent : .Default
    }
    
    func presentWebViewWithURL(URL: NSURL, title: String) {
        webViewVisible = true
        browserViewController.openLink("\(URL)")
        presentWebViewWithTitle(title)
    }
    
    func presentWebViewWithText(text: String, title: String) {
        webViewVisible = true
        browserViewController.renderText(text)
        presentWebViewWithTitle(title)
    }
    
    private func presentWebViewWithTitle(title: String) {
        browserViewController.previousURL = nil
        browserViewController.titleLabel.text = title
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.0, options: [], animations: {
            self.webViewTop.constant = 0.0
            self.setNeedsStatusBarAppearanceUpdate()
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    func dismissWebView() {
        dismissWebView(0.5)
    }
    
    func dismissWebView(duration: Double) {
        webViewVisible = false
        postNotification(TSPerformingNetworkActivityNotification, object: false)
        
        UIView.animateWithDuration(duration, delay: 0.0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.0, options: [], animations: {
            self.webViewTop.constant = self.view.frame.height
            self.view.layoutIfNeeded()
            self.setNeedsStatusBarAppearanceUpdate()
        }, completion: nil)
    }
    
}
