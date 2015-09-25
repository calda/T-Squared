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
    var customHTML: String? = nil
    
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

    override func viewDidLoad() {
        webView.scalesPageToFit = true
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    override func viewWillTransitionToSize(size: CGSize,  withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        self.webView.frame = CGRect(x: 0, y: 70.0, width: size.width, height: size.height - 70.0)
    }
    
    func openLink(link: String, reset: Bool = true) {
        backStack = Stack()
        forwardStack = Stack()
        updateNavButtons()
        guard let url = NSURL(string: link) else { return }
        let request = NSMutableURLRequest(URL: url)
        webView.loadRequest(request)
        webView.hidden = true
        if reset { customHTML = nil }
    }
    
    func renderText(text: String, resetView: Bool = true) {
        if resetView {
            backStack = Stack()
            forwardStack = Stack()
        }
        
        updateNavButtons()
        var html = "<html><body style='font-size:300%'>\(text)</body></html>"
        
        //convert links to hrefs if there aren't any
        let links = linksInText(text)
        if !text.containsString("<a") {
            for link in links {
                let href = "<a href=\(link.text)>\(link.text)</a>"
                html = html.stringByReplacingOccurrencesOfString(link.text, withString: href)
            }
        }
        
        webView.loadHTMLString(html, baseURL: nil)
        customHTML = html
        
        if resetView {
            webView.hidden = true
            
            //if there is only one link on the page, and that link is the entire contents of the page
            //then open that page
            if links.count == 1 && text.cleansed() == links[0].text {
                guard let url = NSURL(string: links[0].text) else { return }
                let request = NSMutableURLRequest(URL: url)
                delay(0.1) { self.titleLabel.text = websiteForLink(links[0].text) }
                webView.loadRequest(request)
                
                previousURL = NSURL(fileURLWithPath: "customHTML")
                backStack.push(previousURL!)
                updateNavButtons()
            }
        }
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
        
        if customHTML != nil && backStack.count == 0 {
            previousURL = NSURL(fileURLWithPath: "customHTML")
        }
        else {
            previousURL = webView.request?.URL
        }
        
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
            
            let currentURL = webView.request?.URL
            
            if let customHTML = customHTML where newURL == NSURL(fileURLWithPath: "customHTML") {
                renderText(customHTML, resetView: false)
            }
            openLink("\(newURL)", reset: false)
            
            if let currentURL = currentURL {
                forwardStack.push(currentURL)
            }
            
            animateNavButton(backButton, toLeft: true)
            updateNavButtons()
        }
    }
    
    @IBAction func forwardPressed(sender: AnyObject) {
        if forwardStack.count > 0 {
            goingForwards = true
            let newURL = forwardStack.pop()!
            let currentURL = webView.request?.URL
            
            openLink("\(newURL)", reset: false)
            animateNavButton(forwardButton, toLeft: false)
            updateNavButtons()
            
            if let currentURL = currentURL where "\(currentURL)" != "about:blank" {
                backStack.push(currentURL)
            }
            else if customHTML != nil {
                backStack.push(NSURL(fileURLWithPath: "customHTML"))
            }
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