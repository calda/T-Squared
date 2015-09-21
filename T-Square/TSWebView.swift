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

class TSWebView : UIViewController, WKNavigationDelegate {
    
    //MARK: - WKNavigationDelegate methods
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var progressBar: UIProgressView!
    var webView: WKWebView!
    
    var backStack: Stack<NSURL> = Stack()
    var forwardStack: Stack<NSURL> = Stack()
    var goingBackwards = false
    var goingForwards = false
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    override func viewWillAppear(animated: Bool) {
        self.webView = WKWebView()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        self.view.addSubview(webView)
        let screen = UIScreen.mainScreen().bounds
        self.webView.frame = CGRect(x: 0, y: 70.0, width: screen.width, height: screen.height - 70.0)
        webView.addObserver(self, forKeyPath: "loading", options: .New, context: nil)
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        webView.removeObserver(self, forKeyPath: "loading")
        webView.removeObserver(self, forKeyPath: "estimatedProgress")
    }
    
    override func viewWillTransitionToSize(size: CGSize,  withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        self.webView.frame = CGRect(x: 0, y: 70.0, width: size.width, height: size.height - 70.0)
    }
    
    func openLink(link: String) {
        guard let url = NSURL(string: link) else { return }
        let request = NSMutableURLRequest(URL: url)
        webView.loadRequest(request)
    }
    
    func getPreviousURL() -> NSURL? {
        let list = webView.backForwardList
        return list.backItem?.URL
    }
    
    func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        let request = navigationAction.request
        let headerFields = request.allHTTPHeaderFields ?? [:]
        
        let makeNew = headerFields["Cookie"] == nil
        decisionHandler(makeNew ? .Cancel : .Allow)
        
        if makeNew {
            let newRequest = NSMutableURLRequest(URL: request.URL!)
            let cookies = NSHTTPCookieStorage.sharedHTTPCookieStorage().cookies ?? []
            let values = NSHTTPCookie.requestHeaderFieldsWithCookies(cookies)
            newRequest.allHTTPHeaderFields = values
            progressBar.setProgress(Float(webView.estimatedProgress),  animated: false)
            
            if !goingBackwards && !goingForwards {
                forwardStack = Stack()
            }
            
            webView.loadRequest(newRequest)
        }
    }
    
    func webView(webView: WKWebView, didCommitNavigation navigation: WKNavigation!) {
        if !goingBackwards && !goingForwards {
            if let previousURL = getPreviousURL() {
                backStack.push(previousURL)
            }
        }
        goingForwards = false
        goingBackwards = false
    }
    
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        updateNavButtons()
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if (keyPath == "loading") {
            updateNavButtons()
        }
        
        if (keyPath == "estimatedProgress") {
            progressBar.setProgress(Float(webView.estimatedProgress),  animated: false)
        }
    }
    
    //MARK: - User Interaction
    
    @IBAction func backPressed(sender: AnyObject) {
        if backStack.count > 0 {
            goingBackwards = true
            let newURL = backStack.pop()!
            
            if let currentURL = webView.URL {
                forwardStack.push(currentURL)
            }
            
            openLink("\(newURL)")
        }
        updateNavButtons()
    }
    
    @IBAction func forwardPressed(sender: AnyObject) {
        if forwardStack.count > 0 {
            goingForwards = true
            let newURL = forwardStack.pop()!
            
            if let currentURL = webView.URL {
                backStack.push(currentURL)
            }
            
            openLink("\(newURL)")
        }
        updateNavButtons()
    }
    
    func updateNavButtons() {
        backButton.enabled = backStack.count > 0
        forwardButton.enabled = forwardStack.count > 0
    }
    
    @IBAction func exitWebView(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func refresh(sender: AnyObject) {
        webView.reload()
    }
    
}