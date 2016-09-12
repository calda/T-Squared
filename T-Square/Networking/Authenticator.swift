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
    static var authFormPost: String?
    static var authLTPost: String?
    
    static var previous: String?
    static var isRunningInBackground = false
    
    static var webViewDelegate: UIWebViewDelegate?
    static var loadedDuoTwoFactor: Bool = false
    static var twoFactorCompletion: ((success: Bool, document: HTMLDocument?) -> ())?
    
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
        } else {
            return
        }
        
        user.prepareForURL()
        password.prepareForURL()
        
        //send HTTP POST for login
        let postString = "&warn=true&lt=\(LT)&execution=e1s1&_eventId=submit&submit=LOGIN&username=\(user)&password=\(password)&submit=LOGIN"
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
            sync() { completion(false, nil) }
        }
            
        //two factor required
        else if response.containsString("duo_iframe") {
            sync {
                
                //can't complete two-factor login in the background
                if Authenticator.isRunningInBackground {
                    sync() { completion(false, nil) }
                    return
                }
                
                //load the Duo Two-Factor page in a Web View
                loginController?.twoFactorWebView.loadHTMLString(response, baseURL: NSURL(string: "https://login.gatech.edu/cas/login"))
                loginController?.twoFactorWebView.superview?.alpha = 1.0
                
                Authenticator.webViewDelegate = TwoFactorWebViewDelegate()
                loginController?.twoFactorWebView.delegate = Authenticator.webViewDelegate!
                
                waitingForTwoFactor = true
                loadedDuoTwoFactor = false
                twoFactorCompletion = completion
            }
        }
        
        //successful login
        else {
            callCompletionForSuccessWithPageContents(response)
        }
    }
    
    static func presentTwoFactorView() {
        if loginController?.twoFactorWebViewCenterConstraint.constant == 0 { return }
        
        UIView.animateWithDuration(0.45, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            loginController?.twoFactorWebViewCenterConstraint.constant = 0
            loginController?.view.layoutIfNeeded()
            loginController?.animateActivityIndicator(on: false)
        }, completion: nil)
    }
    
}


class TwoFactorWebViewDelegate : NSObject, UIWebViewDelegate {
    
    //URL pointed to by the Duo iframe
    //is loaded by the page at runtime
    func iframeSrc(webView: UIWebView) -> String? {
        let content = webView.stringByEvaluatingJavaScriptFromString("document.documentElement.outerHTML")
        let iframe = HttpClient.getInfoFromPage(content ?? "", infoSearch: "<iframe", terminator: ">")
        return HttpClient.getInfoFromPage(iframe ?? "", infoSearch: "src=\"", terminator: "\"")
    }
    
    func webViewDidFinishLoad(webView: UIWebView) {
        let content = webView.stringByEvaluatingJavaScriptFromString("document.documentElement.outerHTML")
        
        //if still waiting on two-factor to complete
        if !Authenticator.loadedDuoTwoFactor {
            let isCorrectPage = content?.containsString("Two-factor login is needed") == true
            let hasFinishedProcessing = iframeSrc(webView) != nil
            
            if isCorrectPage && hasFinishedProcessing {
                Authenticator.loadedDuoTwoFactor = true
                
                //hide everything but the Duo iframe
                let javascript = "$($('body').append($('#duo_iframe')));" +
                                 "$('body > *:not(#duo_iframe)').hide()"
                webView.stringByEvaluatingJavaScriptFromString(javascript)
                
                Authenticator.presentTwoFactorView()
            }
        }
        
        //successful login
        if let content = content where content.containsString("My Workspace") == true || content.containsString("Log Out") == true {
            let document = Kanna.HTML(html: content, encoding: NSUTF8StringEncoding)
            Authenticator.twoFactorCompletion?(success: true, document: document)
        }
    }
}


//MARK: - Custom NSURLCache that swizzles the CSS of the Duo iframe

class SwizzlingNSURLCache : NSURLCache {
    
    override func cachedResponseForRequest(request: NSURLRequest) -> NSCachedURLResponse? {
        
        //intercept and swizzle CSS for Duo Two-Factor
        if let url = request.URL where url.absoluteString?.containsString("base-v3.css") == true {
            guard let pageContents = HttpClient(url: url.absoluteString!).sendGet() else { return nil }
            
            let newCss = ".base-navigation { display: none !important; }" +
                         ".base-main { top: 10px !important; width: 80% !important; margin: 0 auto !important; }" +
                         ".base-wrapper { border: 0 !important; }" +
                         ".phone-label { display: none !important; }"
            
            var swizzled = pageContents + newCss
            
            //replace a bit because it doesn't want to be overriden by re-declaration
            swizzled = swizzled.stringByReplacingOccurrencesOfString(".stay-logged-in {\n  margin-top: -6px; }", withString: ".stay-logged-in {\n  margin-top: 35x; }")
            
            //pass the modified file up the chain as if it was authentic
            let response = NSURLResponse(URL: url, MIMEType: "text/css", expectedContentLength: -1, textEncodingName: nil)
            guard let data = NSString(string: swizzled).dataUsingEncoding(NSUTF8StringEncoding) else { return nil }
            let cachedResponse = NSCachedURLResponse(response: response, data: data)
            
            return cachedResponse
        }
            
        else {
            return super.cachedResponseForRequest(request)
        }
    }
}
