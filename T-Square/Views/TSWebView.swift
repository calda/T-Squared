//
//  TSWebView.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 9/20/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation
import UIKit
import WebKit
import Kanna

class TSWebView : UIViewController, UIWebViewDelegate {
    
    //MARK: - WKNavigationDelegate methods
    
    var loginController: LoginViewController!
    @IBOutlet weak var webView: UIWebView!
    var previousURL: URL? = nil
    var customHTML: String? = nil
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var progressBar: UIProgressView!
    
    var backStack: Stack<URL> = Stack()
    var forwardStack: Stack<URL> = Stack()
    var goingBackwards = false
    var goingForwards = false
    var refreshing = false
    var scrollToBottomWhenDoneLoading = false
    
    var performAfterNextLoad: (() -> ())?

    func setActivityCircleVisible(_ visible: Bool) {
        let scale: CGFloat = visible ? 1.0 : 0.1
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        
        UIView.animate(withDuration: visible ? 0.7 : 0.4, delay: 0.0, usingSpringWithDamping: visible ? 0.5 : 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.loginController.activityCircle.transform = transform
            self.loginController.activityCircle.alpha = visible ? 1.0 : 0.0
        }, completion: nil)
    }
    
    func setContentVisible(_ visible: Bool) {
        delay(0.2) {
            self.webView.isHidden = !visible
        }
    }
    
    override func viewDidLoad() {
        webView.scalesPageToFit = true
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    override func viewWillTransition(to size: CGSize,  with coordinator: UIViewControllerTransitionCoordinator) {
        self.webView.frame = CGRect(x: 0, y: 70.0, width: size.width, height: size.height - 70.0)
    }
    
    func openLink(_ link: String, reset: Bool = true) {
        if reset {
            customHTML = nil
            backStack = Stack()
            forwardStack = Stack()
            updateNavButtons()
        }
        
        guard let url = URL(string: link) else { return }
        let request = NSMutableURLRequest(url: url)
        webView.loadRequest(request as URLRequest)
        self.webView.isHidden = true
        
        //on the t-square site, using force.classic also redirects you back to the home page
        if link.contains("?force.classic=yes") && link.contains("gatech") {
            performAfterNextLoad = {
                self.setContentVisible(false)
                var newLink = link.replacingOccurrences(of: "?force.classic=yes", with: "")
                newLink = newLink.replacingOccurrences(of: "/pda/", with: "/site/")
                self.openLink(newLink, reset: reset)
            }
        }
    }
    
    func renderText(_ text: String, resetView: Bool = true) {
        if resetView {
            backStack = Stack()
            forwardStack = Stack()
        }
        
        updateNavButtons()
        var html = "<html><body style='font-size:300%'>\(text)</body></html>"
        
        //convert links to hrefs if there aren't any
        let links = linksInText(text)
        if !text.contains("<a") {
            for link in links {
                let href = "<a href=\(link.text)>\(link.text)</a>"
                html = html.replacingOccurrences(of: link.text, with: href)
            }
        }
        
        webView.loadHTMLString(html, baseURL: nil)
        customHTML = html
        
        if resetView {
            self.setContentVisible(false)
            
            //if there is only one link on the page, and that link is the entire contents of the page
            //then open that page
            if links.count == 1 && text.cleansed() == links[0].text {
                guard let url = URL(string: links[0].text) else { return }
                let request = NSMutableURLRequest(url: url)
                delay(0.1) { self.titleLabel.text = websiteForLink(links[0].text) }
                webView.loadRequest(request as URLRequest)
                
                previousURL = URL(fileURLWithPath: "customHTML")
                backStack.push(previousURL!)
                updateNavButtons()
            }
        }
    }
    
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        
        //the UIWebView can't display PDFs, so we have to intercept them and open the request in a Document View Controller
        if let url = request.url {
            let knownFileExtensions = ["pdf", "ppt", "pptx", "xls", "xlsx", "png", "jpg", "jpeg"]
            for ext in knownFileExtensions {
                if "\(url)".lowercased().hasSuffix(".\(ext)") {
                    loginController.classesViewController.presentDocumentFromURL(url)
                    return false
                }
            }
        }
        
        return true
    }
    
    func webViewDidStartLoad(_ webView: UIWebView) {
        setActivityCircleVisible(true)
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        self.setContentVisible(true)
        
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
            previousURL = URL(fileURLWithPath: "customHTML")
        }
        else {
            previousURL = webView.request?.url
        }
        
        updateNavButtons()
        setActivityCircleVisible(false)
        webView.scrollView.contentOffset = CGPoint(x: 0, y: 0)
        
        if scrollToBottomWhenDoneLoading {
            scrollToBottomWhenDoneLoading = false
            
            //scroll to the bottom
            let scrollView = webView.scrollView
            let contentHeight = scrollView.contentSize.height
            let viewHeight = webView.frame.height
            
            UIView.animateWithDuration(1.2, delay: 0.5, usingSpringWithDamping: 0.75) {
                scrollView.contentOffset = CGPoint(x: 0, y: contentHeight - viewHeight)
            }
        }
        
        performAfterNextLoad?()
        performAfterNextLoad = nil
    }

    //MARK: - User Interaction
    
    @IBAction func backPressed(_ sender: AnyObject) {
        if backStack.count > 0 {
            goingBackwards = true
            let newURL = backStack.pop()!
            
            let currentURL = webView.request?.url
            
            if let customHTML = customHTML, newURL == URL(fileURLWithPath: "customHTML") {
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
    
    @IBAction func forwardPressed(_ sender: AnyObject) {
        if forwardStack.count > 0 {
            goingForwards = true
            let newURL = forwardStack.pop()!
            let currentURL = webView.request?.url
            
            openLink("\(newURL)", reset: false)
            animateNavButton(forwardButton, toLeft: false)
            updateNavButtons()
            
            if let currentURL = currentURL, "\(currentURL)" != "about:blank" {
                backStack.push(currentURL)
            }
            else if customHTML != nil {
                backStack.push(URL(fileURLWithPath: "customHTML"))
            }
        }
    }
    
    func animateNavButton(_ button: UIButton, toLeft: Bool) {
        let offset: CGFloat = toLeft ? -25.0 : 25.0
        let originalOrigin = button.frame.origin
        let tempOrigin = CGPoint(x: originalOrigin.x + offset, y: originalOrigin.y)
        
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            button.frame.origin = tempOrigin
        }, completion: nil)
        
        UIView.animate(withDuration: 0.6, delay: 0.4, usingSpringWithDamping: 0.4, initialSpringVelocity: 0.0, options: [], animations: {
            button.frame.origin = originalOrigin
        }, completion: nil)
    }
    
    func updateNavButtons() {
        backButton.isEnabled = backStack.count > 0
        forwardButton.isEnabled = forwardStack.count > 0
    }
    
    @IBAction func exitWebView(_ sender: AnyObject) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: TSDismissWebViewNotification), object: nil)
    }
    
    @IBAction func openShareSheet(_ sender: UIButton) {
        do {
            var shareItems: [AnyObject] = []
            var activities: [UIActivity] = []
            
            if let currentURL = webView.request?.url, currentURL != URL(string: "about:blank") {
                shareItems.append(currentURL as AnyObject)
                activities.append(SafariActivity())
            }
            else if let customHTML = customHTML {
                let customDoc = try Kanna.HTML(html: customHTML, encoding: String.Encoding.utf8)
                let customText = customDoc.text
                shareItems.append(customText as AnyObject)
            }
            
            let shareSheet = UIActivityViewController(activityItems: shareItems, applicationActivities: activities)
            if iPad() {
                let popup = UIPopoverController(contentViewController: shareSheet)
                popup.present(from: sender.frame, in: sender.superview!, permittedArrowDirections: .up, animated: true)
            } else {
                self.present(shareSheet, animated: true, completion: nil)
            }
        } catch {
            print("cannot open share sheet")
        }
        
    }
    
}

class SafariActivity : UIActivity {
    
    var URL: Foundation.URL?
    
    override var activityType: UIActivityType? {
        return UIActivityType.init("SafariActivity")
    }
        
    override var activityTitle : String? {
        return "Open in Safari"
    }
    
    override var activityImage : UIImage? {
        return UIImage(named: "action-safari")
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        for item in activityItems {
            if let item = item as? Foundation.URL {
                URL = item
            }
        }
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        for item in activityItems {
            if let _ = item as? Foundation.URL {
                return true
            }
        }
        return false
    }
    
    override func perform() {
        if let URL = URL {
            UIApplication.shared.openURL(URL)
        }
    }
    
}

