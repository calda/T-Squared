//
//  ViewController.swift
//  T-Square
//
//  Created by Cal on 8/26/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import UIKit

class LoginViewController: UIViewController {

    @IBOutlet weak var formCenter: NSLayoutConstraint!
    @IBOutlet weak var backgroundBottom: NSLayoutConstraint!
    @IBOutlet weak var formBlurView: UIVisualEffectView!
    @IBOutlet weak var formView: UIView!
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidAppear(animated: Bool) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardHeightChanged:", name: UIKeyboardWillChangeFrameNotification, object: nil)
    }
    
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
        animateFormSubviewsWithDuration(0.5, hidden: true)
        animateActivityIndicator(on: true)
        
        dispatch_async(TSNetworkQueue, {
            TSReader.authenticatedReader(user: self.usernameField.text!, password: self.passwordField.text!, completion: { reader in
                
                if let reader = reader {
                    self.animateFormSubviewsWithDuration(0.5, hidden: false)
                    self.animateActivityIndicator(on: false)
                    reader.getClasses()
                }
                
                else {
                    shakeView(self.formView)
                    self.animateFormSubviewsWithDuration(0.5, hidden: false)
                    self.animateActivityIndicator(on: false)
                }
                
            })
        })
    }
    
    func animateFormSubviewsWithDuration(duration: Double, hidden: Bool) {
        for subview in formView.subviews {
            if !(subview is UIVisualEffectView) {
                UIView.animateWithDuration(duration) {
                    subview.alpha = hidden ? 0.0 : (subview.tag == 1 ? 0.5 : 1.0)
                }
            }
        }
    }
    
    func animateActivityIndicator(on on: Bool) {
        
        var originalIndicatorPosition: CGPoint {
            return CGPointMake(CGRectGetMidX(formView.frame) - activityIndicator.frame.width / 2.0, CGRectGetMidY(formView.frame) - activityIndicator.frame.height / 2.0)
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
}

