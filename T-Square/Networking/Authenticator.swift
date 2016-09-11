//
//  Authenticator.swift
//  T-Square
//
//  Created by Cal on 9/10/16.
//  Copyright © 2016 Georgia Tech. All rights reserved.
//

import Foundation
import Kanna
import UIKit

class Authenticator {
    
    //MARK: - Handling Login
    static var sessionID: String?
    static var authFormPost: String?
    static var authLTPost: String?
    
    static var previous: String?
    static var isRunningInBackground = false
    
    static var webViewDelegate: UIWebViewDelegate?
    static var twoFactorURL: String?
    
    static var loginController: LoginViewController? {
        return UIApplication.sharedApplication().keyWindow?.rootViewController as? LoginViewController
    }
    
    //this function is gigantic but it'll have to do.
    static func authenticateWithUsername(username: String, password userPassword: String, completion: (Bool, HTMLDocument?) -> ()) {
        var user = username
        var password = userPassword
        var didCompletion = false
        var waitingForTwoFactor = false
        
        //call the completion before exiting scope
        defer {
            if !didCompletion && !waitingForTwoFactor {
                if isRunningInBackground {
                    completion(false, nil)
                } else {
                    sync() { completion(false, nil) }
                }
            }
        }
        
        //request the login page
        let client = HttpClient(url: "https://login.gatech.edu/cas/login?service=https%3A%2F%2Ft-square.gatech.edu%2Fsakai-login-tool%2Fcontainer")
        guard let loginScreenText = client.sendGet() else {
            if self.isRunningInBackground { return }
            NSNotificationCenter.defaultCenter().postNotificationName(TSNetworkErrorNotification, object: nil)
            return
        }
        
        func callCompletionForSuccessWithPageContents(successContents: String) {
            didCompletion = true
            
            sessionID = nil
            authFormPost = nil
            authLTPost = nil
            
            if isRunningInBackground {
                //Calling completion on current thread to resolve background activity
                completion(true, HTML(html: successContents, encoding: NSUTF8StringEncoding))
            }
            else {
                sync {
                    //Calling completion synchronously
                    completion(true, HTML(html: successContents, encoding: NSUTF8StringEncoding))
                }
            }
        }
        
        //there are some cases where the user is logged in to GT CAS
        ///but *not* logged in to T-Square
        //so when we login to T-Square, CAS completes the login automatically
        
        //if the login page has the word "Log Out", then our work is already done
        if loginScreenText.containsString("Log Out") {
            callCompletionForSuccessWithPageContents(loginScreenText)
            return
        }
        
        //back to the standard login flow
        //find the LT value and page for form post
        
        let loginScreen = loginScreenText as NSString
        
        var formPost: String
        var LT: String
        
        //get page form
        let pageFormInfo = HttpClient.getInfoFromPage(loginScreen, infoSearch: "<form id=\"fm1\" class=\"fm-v clearfix\" action=\"")
        let LT_info = HttpClient.getInfoFromPage(loginScreen, infoSearch: "value=\"LT")
        
        if let previousFormPost = Authenticator.authFormPost {
            formPost = previousFormPost
        } else if let pageFormAddress = pageFormInfo {
            formPost = pageFormAddress
            Authenticator.authFormPost = formPost
        } else {
            return
        }
        
        //get LT
        if let previousLT = Authenticator.authLTPost {
            LT = previousLT
        } else if let LT_part = LT_info {
            LT = "LT" + LT_part
            Authenticator.authLTPost = LT
        }
        else {
            return
        }
        
        user.prepareForURL()
        password.prepareForURL()
        
        //send HTTP POST for login
        let postString = "?warn=true&lt=\(LT)&execution=e1s1&_eventId=submit&submit=LOGIN&username=\(user)&password=\(password)&submit=LOGIN&_eventId=submit"
        let loginClient = HttpClient(url: "https://login.gatech.edu\(formPost)\(postString)")
        
        guard let response = loginClient.sendGet() else {
            //synchronous network error even though in background thread
            //because the app locks up when calling sync{ } for some reason
            (UIApplication.sharedApplication().windows[0].rootViewController as? LoginViewController)?.syncronizedNetworkErrorRecieved()
            return
        }
        
        //incorrect password
        if response.containsString("Incorrect login or disabled account.") || response.containsString("Login requested by:") {
            didCompletion = true
            Authenticator.sessionID = HttpClient.getInfoFromPage(formPost, infoSearch: "jsessionid=", terminator: "?")
            sync() { completion(false, nil) }
        }
            
            //two factor required
        else if response.containsString("duo_iframe") {
            Authenticator.twoFactorURL = nil
            
            sync {
                //spin up a UIWebView
                //the response container an iframe, but that iframe's src is loaded via javascript
                
                let webView = UIWebView()
                webView.frame = CGRect.zero
                webView.loadHTMLString(response, baseURL: NSURL(string: "https://login.gatech.edu/cas/login"))
                
                Authenticator.webViewDelegate = TwoFactorWebViewDelegate()
                webView.delegate = Authenticator.webViewDelegate!
                Authenticator.twoFactorURL = nil
                waitingForTwoFactor = true
                
                loginController?.view.addSubview(webView)
                
                delay(5.0) {
                    if Authenticator.twoFactorURL == nil {
                        completion(true, nil)
                    }
                }
                
            }
        }
            //successful login
        else {
            callCompletionForSuccessWithPageContents(response)
        }
    }

    static func continueWithTwoFactor() {
        print(Authenticator.twoFactorURL)
        
        guard let twoFactorURL = Authenticator.twoFactorURL else { return }
        
        let request = NSURLRequest(URL: NSURL(string: twoFactorURL)!)
        loginController?.twoFactorWebView.loadRequest(request)
        loginController?.twoFactorWebView.superview?.alpha = 1.0
        loginController?.twoFactorWebView.scrollView.scrollEnabled = false
        Authenticator.webViewDelegate = TwoFactorWebViewDelegate()
        loginController?.twoFactorWebView.delegate = Authenticator.webViewDelegate!
    }
    
    static func presentTwoFactorView() {
        UIView.animateWithDuration(0.3, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            loginController?.twoFactorWebViewCenterConstraint.constant = 0
            loginController?.view.layoutIfNeeded()
            loginController?.animateActivityIndicator(on: false)
        }, completion: nil)
    }
    
}

class TwoFactorWebViewDelegate : NSObject, UIWebViewDelegate {
    
    func iframeSrc(webView: UIWebView) -> String? {
        let content = webView.stringByEvaluatingJavaScriptFromString("document.documentElement.outerHTML")
        let iframe = HttpClient.getInfoFromPage(content ?? "", infoSearch: "<iframe", terminator: ">")
        return HttpClient.getInfoFromPage(iframe ?? "", infoSearch: "src=\"", terminator: "\"")
    }
    
    func webViewDidFinishLoad(webView: UIWebView) {
        
        let content = webView.stringByEvaluatingJavaScriptFromString("document.documentElement.outerHTML")
        if (content?.containsString("Send Me a Push") == true) {
            
            //hide content on the page
            let javascript = "$(document).ready(function() { $('.base-navigation').hide(); $('.base-main').css('top', '0'); $('.base-main').css('width', '75%'); $('.base-main').css('margin', '0 auto'); $('.stay-logged-in').parent().hide(); $('.base-wrapper').css('border', '0') })"
            webView.stringByEvaluatingJavaScriptFromString(javascript)
            
            Authenticator.presentTwoFactorView()
        }
        
        else {
            if iframeSrc(webView) != nil {
                webView.stopLoading()
                Authenticator.twoFactorURL = iframeSrc(webView)!
                webView.delegate = nil
                Authenticator.webViewDelegate = nil
                Authenticator.continueWithTwoFactor()
            }
        }
        
    }
    
}

