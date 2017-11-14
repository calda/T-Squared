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
    @IBOutlet weak var twoFactorWebView: UIWebView!
    @IBOutlet weak var twoFactorWebViewCenterConstraint: NSLayoutConstraint!
    
    
    //MARK: - Preparing the View Controller
    
    override func viewDidLoad() {
        //transition from old password scheme
        let data = UserDefaults.standard
        
        if let savedUsername = data.string(forKey: "edu.gatech.cal.username"),
           let savedPassword = data.string(forKey: "edu.gatech.cal.password") {
            saveCredentials(username: savedUsername, password: savedPassword)
        }
        
        //nil-out the current values and close up that hole
        data.setValue(nil, forKey: "edu.gatech.cal.username")
        data.setValue(nil, forKey: "edu.gatech.cal.password")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if animated { return }
        if TSAuthenticatedReader != nil { return } //we're already authenticated
        
        //double check we aren't already authenticated
        let rootPage = "http://t-square.gatech.edu/portal/pda/"
        let pageContents = HttpClient.contentsOfPage(rootPage, postNotificationOnError: false)?.toHTML
        var validConnection = true
        
        if let contents = pageContents {
            if contents.contains("Log Out") {
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
        self.webViewTop.constant = UIScreen.main.bounds.height
        self.containerLeading.constant = UIScreen.main.bounds.width
        self.view.layoutIfNeeded()
        
        originalLoggingInText = loggingInText.attributedText!
        let currentUsername = TSLaunchedUsername
        usernameField.text = currentUsername
        
        if let (savedUsername, savedPassword) = savedCredentials(), currentUsername == nil || currentUsername == "" || currentUsername == savedUsername {
            usernameField.text = savedUsername
            passwordField.text = savedPassword
            
            if validConnection {
                animateFormSubviewsWithDuration(0.0, hidden: true)
                animateActivityIndicator(on: true)
                doLogin(newLogin: false)
            }
        }
        
        UIView.animate(withDuration: 0.7, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [], animations: {
            self.formCenter.constant = 10.0
            self.view.layoutIfNeeded()
        }, completion: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.showLogoutAlert), name: NSNotification.Name(rawValue: TSLogoutNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.dismissWebView as (LoginViewController) -> () -> ()), name: NSNotification.Name(rawValue: TSDismissWebViewNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.keyboardHeightChanged(_:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.centerForm), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.networkErrorRecieved), name: NSNotification.Name(rawValue: TSNetworkErrorNotification), object: nil)
        
        activityCircle.isHidden = false
        activityCircle.layer.cornerRadius = 25.0
        activityCircle.layer.masksToBounds = true
        activityCircle.transform = CGAffineTransform(scaleX: 0.0, y: 0.0)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let classes = segue.destination as? ClassesViewController {
            classes.loginController = self
            classesViewController = classes
        }
        if let browser = segue.destination as? TSWebView {
            browser.loginController = self
            self.browserViewController = browser
        }
    }
    
    //MARK: - Animating and processing form input
    
    @objc func keyboardHeightChanged(_ notification: Notification) {
        //ignore if the classes controller is visible
        if self.containerLeading.constant == 0.0 { return }
        
        if let userInfo = notification.userInfo,
           let keyboardFrame = (userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            
            let keyboardHeight = keyboardFrame.height
            let newConstant = -10 - (keyboardHeight / (is4S() ? 2.5 : 3.0))
            
            if newConstant == formCenter.constant { return }
            
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
                self.formCenter.constant = newConstant
                self.backgroundBottom.constant = keyboardHeight - 100.0
                self.view.layoutIfNeeded()
            }, completion: nil)
            
        }
    }
    
    @objc func centerForm() {
        UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.formCenter.constant = -10.0
            self.backgroundBottom.constant = 0.0
            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    @IBAction func switchToPasswordInput(_ sender: AnyObject) {
        passwordField.becomeFirstResponder()
    }
    
    @IBAction func loginPressed(_ sender: AnyObject) {
        doLogin(newLogin: true)
    }
    
    func doLogin(newLogin: Bool) {
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
            let alert = UIAlertController(title: "Nice Try, you trickster", message: "George Burdell, is that you???", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "You found me out", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        //animate the activity indicator
        animateFormSubviewsWithDuration(0.5, hidden: true)
        delay(0.2) { self.animateActivityIndicator(on: true) }
        
        //attempt to authenticate
        TSNetworkQueue.async(execute: {
            TSReader.authenticatedReader(user: self.usernameField.text!, password: self.passwordField.text!, isNewLogin: newLogin, completion: { reader in
                
                //successful login
                if let reader = reader {
                    let loginCount = UserDefaults.standard.integer(forKey: TSLoginCountKey)
                    UserDefaults.standard.set(loginCount + 1, forKey: TSLoginCountKey)
                    
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
    
    @objc func networkErrorRecieved() {
        sync {
            self.syncronizedNetworkErrorRecieved()
        }
    }
    
    func syncronizedNetworkErrorRecieved(showAlert: Bool = true) {
        self.animateFormSubviewsWithDuration(0.5, hidden: false)
        self.animateActivityIndicator(on: false)
        
        let existingUsername = self.usernameField.text
        let existingPassword = self.passwordField.text
        
        //prevent the username and password from being cleared out
        delay(0.5) {
            self.usernameField.text = existingUsername
            self.passwordField.text = existingPassword
        }
        
        if showAlert {
            let alert = UIAlertController(title: "Couldn't connect to T-Square", message: "Are you connected to the internet?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: nil))
            alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in openSettings() }))
            self.present(alert, animated: true, completion: nil)
        }
        
        self.classesViewController.DISABLE_PUSHES = true
    }
    
    func setSavedCredentials(correct: Bool) {
        if !correct || !saveCredentialsSwitch.isOn {
            saveCredentials(username: nil, password: nil)
        }
        else {
            saveCredentials(username: usernameField.text, password: passwordField.text)
        }
    }
    
    func animateFormSubviewsWithDuration(_ duration: Double, hidden: Bool) {
        for subview in formView.subviews {
            if !(subview is UIVisualEffectView) && subview.tag != -1 {
                UIView.animate(withDuration: duration, animations: {
                    subview.alpha = hidden ? 0.0 : (subview.tag == 1 ? 0.3 : 1.0)
                }) 
            }
        }
        UIView.animate(withDuration: duration, animations: {
            self.loggingInText.alpha = hidden ? 1.0 : 0.0
        }) 
        let loggingInString = originalLoggingInText.mutableCopy() as! NSMutableAttributedString
        loggingInString.replaceCharacters(in: NSMakeRange(14, 8), with: usernameField.text!)
        self.loggingInText.attributedText = loggingInString
    }
    
    func animateActivityIndicator(on: Bool) {
        
        var originalIndicatorPosition: CGPoint {
            return CGPoint(x: formView.frame.midX - activityIndicator.frame.width / 2.0, y: (formView.frame.midY - activityIndicator.frame.height / 2.0) + 50.0)
        }
        
        if on {
            let originalPosition = originalIndicatorPosition
            let animationStart = CGPoint(x: originalPosition.x, y: originalPosition.y + 50)
            activityIndicator.frame.origin = animationStart
            UIView.animate(withDuration: 0.7, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [], animations: {
                self.activityIndicator.frame.origin = originalPosition
                self.activityIndicator.alpha = 1.0
            }, completion: nil)
        }
        else {
            let originalPosition = originalIndicatorPosition
            let animationEnd = CGPoint(x: originalPosition.x, y: originalPosition.y + 50)
            UIView.animate(withDuration: 0.7, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [], animations: {
                self.activityIndicator.frame.origin = animationEnd
                self.activityIndicator.alpha = 0.0
            }, completion: nil)
        }
    }
    
    @IBAction func defocusTextViews(_ sender: UITapGestureRecognizer) {
        let touch = sender.location(in: self.view)
        let blurFrame = self.view.convert(formBlurView.frame, from: formBlurView.superview!)
        if !blurFrame.contains(touch) {
            usernameField.resignFirstResponder()
            passwordField.resignFirstResponder()
            centerForm()
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    //MARK: - Switching Views
    
    func presentClassesView(_ reader: TSReader) {
        tapRecognizer.isEnabled = false
        var classes: [Class] = []
        var loadAttempt = 0
        while classes.count == 0 && loadAttempt < 4 && !reader.actuallyHasNoClasses {
            loadAttempt += 1
            classes = reader.getActiveClasses()
            
            if classes.count == 0 {
                reader.checkIfHasNoClasses()
            }
            
            if loadAttempt > 2 {
                HttpClient.clearCookies()
            }
        }
        
        if loadAttempt >= 4 {
            //present an alert and then exit the app if the classes aren't loading
            //this means a failed authentication looked like it passed
            //AKA I have no idea what happened
            let message = "This happens every now and then. Please restart T-Squared and try again. If this keeps happening, please send an email to cal@calstephens.tech"
            let alert = UIAlertController(title: "There was a problem logging you in.", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Restart", style: .default, handler: { _ in
                //crash
                let null: Int! = nil
                null.threeCharacterString()
            }))
            self.present(alert, animated: true, completion: nil)
            self.setSavedCredentials(correct: false)
            return
        }
        
        classesViewController.classes = classes
        classesViewController.reloadTable()
        
        //open to the shortcut item if there is one queued
        if let delegate = UIApplication.shared.delegate as? AppDelegate {
            delegate.openShortcutItemIfPresent()
        }
        
        animatePresentClassesView()
        classesViewController.loadAnnouncements(reloadClasses: false, withInlineActivityIndicator: true)
    }
    
    func animatePresentClassesView() {
        UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.formView.alpha = 0.0
            self.formView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            self.containerLeading.constant = 0.0
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    func unpresentClassesView() {
        unpresentClassesView(0.5)
    }
    
    func unpresentClassesView(_ duration: Double) {
        UIView.animate(withDuration: duration, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.formView.alpha = 1.0
            self.formView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            self.containerLeading.constant = self.view.frame.width
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    //logout from gatech login service and trash saved passwords
    @objc func showLogoutAlert() {
        let alert = UIAlertController(title: nil, message: "Are you sure you want to log out?", preferredStyle: iPad() ? .alert : .actionSheet)
        alert.addAction(UIAlertAction(title: "Log out", style: .destructive, handler: { _ in self.logout() }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func logout() {
        self.classesViewController.announcements = []
        self.classesViewController.classes = nil
        URLCache.shared.removeAllCachedResponses()
        HttpClient.clearCookies()
        
        Authenticator.authFormPost = nil
        Authenticator.authLTPost = nil
        TSAuthenticatedReader = nil
        
        self.usernameField.text = ""
        self.passwordField.text = ""
        self.twoFactorWebViewCenterConstraint.constant = 220.0
        self.view.layoutIfNeeded()
        self.setSavedCredentials(correct: false)
        UserDefaults.standard.setValue(nil, forKey: TSClassOpenCountKey)
        Class.updateShortcutItems()
        
        unpresentClassesView()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
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
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return webViewVisible ? .lightContent : .default
    }
    
    func presentWebViewWithURL(_ URL: Foundation.URL, title: String) {
        webViewVisible = true
        browserViewController.openLink("\(URL)")
        presentWebViewWithTitle(title)
    }
    
    func presentWebViewWithText(_ text: String, title: String) {
        webViewVisible = true
        browserViewController.renderText(text)
        presentWebViewWithTitle(title)
    }
    
    fileprivate func presentWebViewWithTitle(_ title: String) {
        browserViewController.previousURL = nil
        browserViewController.titleLabel.text = title
        UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.0, options: [], animations: {
            self.webViewTop.constant = 0.0
            self.setNeedsStatusBarAppearanceUpdate()
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    @objc func dismissWebView() {
        dismissWebView(0.5)
    }
    
    func dismissWebView(_ duration: Double) {
        webViewVisible = false
        postNotification(TSPerformingNetworkActivityNotification, object: false as AnyObject)
        classesViewController.setActivityIndicatorVisible(false)
        
        UIView.animate(withDuration: duration, delay: 0.0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.0, options: [], animations: {
            self.webViewTop.constant = self.view.frame.height
            self.view.layoutIfNeeded()
            self.setNeedsStatusBarAppearanceUpdate()
        }, completion: nil)
    }
    
}
