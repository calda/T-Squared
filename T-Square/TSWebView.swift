//
//  WebView.swift
//  T-Square
//
//  Created by Cal on 9/20/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import UIKit
import WebKit

class TSWebView : UIViewController, UIWebViewDelegate {
    
    //MARK: - WKNavigationDelegate methods
    
    var loginController: LoginViewController!
    @IBOutlet weak var webView: UIWebView!
    var previousURL: NSURL? = nil
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var refreshButton: UIButton!
    
    var backStack: Stack<NSURL> = Stack()
    var forwardStack: Stack<NSURL> = Stack()
    var goingBackwards = false
    var goingForwards = false
    var refreshing = false
    var scrollToBottomWhenDoneLoading = false

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    override func viewWillTransitionToSize(size: CGSize,  withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        self.webView.frame = CGRect(x: 0, y: 70.0, width: size.width, height: size.height - 70.0)
    }
    
    func openLink(link: String) {
        backStack = Stack()
        forwardStack = Stack()
        updateNavButtons()
        guard let url = NSURL(string: link) else { return }
        let request = NSMutableURLRequest(URL: url)
        webView.loadRequest(request)
        webView.hidden = true
    }
    
    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        return true
    }
    
    func webViewDidStartLoad(webView: UIWebView) {
        loginController.setActivityCircleVisible(true)
    }
    
    func webViewDidFinishLoad(webView: UIWebView) {
        webView.hidden = false
        
        if !goingBackwards && !goingForwards {
            if let previousURL = previousURL {
                backStack.push(previousURL)
            }
            forwardStack = Stack()
        }
        goingForwards = false
        goingBackwards = false
        refreshing = false
        previousURL = webView.request?.URL
        updateNavButtons()
        loginController.setActivityCircleVisible(false)
        webView.scrollView.contentOffset = CGPointMake(0, 0)
        
        if scrollToBottomWhenDoneLoading {
            scrollToBottomWhenDoneLoading = false
            
            //scroll to the bottom
            let scrollView = webView.scrollView
            let contentHeight = scrollView.contentSize.height
            let viewHeight = webView.frame.height
            
            UIView.animateWithDuration(1.2, delay: 0.5, usingSpringWithDamping: 0.75) {
                scrollView.contentOffset = CGPointMake(0, contentHeight - viewHeight)
            }
            
        }
    }

    //MARK: - User Interaction
    
    @IBAction func backPressed(sender: AnyObject) {
        if backStack.count > 0 {
            goingBackwards = true
            let newURL = backStack.pop()!
            
            if let currentURL = webView.request?.URL {
                forwardStack.push(currentURL)
            }
            
            openLink("\(newURL)")
            
            animateNavButton(backButton, toLeft: true)
            updateNavButtons()
        }
    }
    
    @IBAction func forwardPressed(sender: AnyObject) {
        if forwardStack.count > 0 {
            goingForwards = true
            let newURL = forwardStack.pop()!
            
            if let currentURL = webView.request?.URL {
                backStack.push(currentURL)
            }
            
            openLink("\(newURL)")
            animateNavButton(forwardButton, toLeft: false)
            updateNavButtons()
        }
    }
    
    func animateNavButton(button: UIButton, toLeft: Bool) {
        let offset: CGFloat = toLeft ? -25.0 : 25.0
        let originalOrigin = button.frame.origin
        let tempOrigin = CGPointMake(originalOrigin.x + offset, originalOrigin.y)
        
        UIView.animateWithDuration(0.4, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            button.frame.origin = tempOrigin
        }, completion: nil)
        
        UIView.animateWithDuration(0.6, delay: 0.4, usingSpringWithDamping: 0.4, initialSpringVelocity: 0.0, options: [], animations: {
            button.frame.origin = originalOrigin
        }, completion: nil)
    }
    
    func updateNavButtons() {
        backButton.enabled = backStack.count > 0
        forwardButton.enabled = forwardStack.count > 0
    }
    
    @IBAction func exitWebView(sender: AnyObject) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSDismissWebViewNotification, object: nil)
    }
    
    @IBAction func refresh(sender: AnyObject) {
        refreshing = true
        webView.reload()
        
        let transform = CGAffineTransformRotate(refreshButton.transform, CGFloat(-M_PI))
        UIView.animateWithDuration(0.7, delay: 0.0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.0, options: [], animations: {
            self.refreshButton.transform = transform
        }, completion: nil)
    }
    
}