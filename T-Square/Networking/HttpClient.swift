//
//  HttpClient.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 8/26/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation
import Kanna
import UIKit

let TSNetworkQueue = dispatch_queue_create("edu.gatech.cal.network-queue", DISPATCH_QUEUE_CONCURRENT)

class HttpClient {
    
    //MARK: - HTTP implementation
    
    private var url: NSURL?
    private var session: NSURLSession
    
    internal init(url: String, useMobile: Bool = true) {
        self.url = NSURL(string: url)
        
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.requestCachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData
        if useMobile {
            config.HTTPAdditionalHeaders = ["User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 8_0 like Mac OS X) AppleWebKit/600.1.3 (KHTML, like Gecko) Version/8.0 Mobile/12A4345d Safari/600.1.4"]
        }
        self.session = NSURLSession(configuration: config)
        NSURLCache.setSharedURLCache(SwizzlingNSURLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil))
        
        session.configuration.HTTPShouldSetCookies = true
        session.configuration.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicy.Always
        session.configuration.HTTPCookieStorage?.cookieAcceptPolicy = NSHTTPCookieAcceptPolicy.Always
        session.configuration.requestCachePolicy = .ReloadIgnoringLocalCacheData
    }
    
    internal func sendGet() -> String? {
        NSURLCache.sharedURLCache().removeAllCachedResponses()
        
        var attempts = 0
        var failed = false
        var stopTrying = false
        var ready = false
        var content: String!
        guard let url = self.url else { return nil }
        
        let request = NSMutableURLRequest(URL: url, cachePolicy: .ReloadIgnoringLocalCacheData, timeoutInterval: 5.0)
        
        while !stopTrying && !ready {
            
            failed = false
            
            let task = session.dataTaskWithRequest(request) {
                (data, response, error) -> Void in
                if let data = data {
                    if let loadedContent = NSString(data: data, encoding: NSASCIIStringEncoding) {
                        content = loadedContent as String
                        ready = true
                        return
                    }
                }
                
                attempts += 1
                failed = true
                if attempts >= 3 {
                    stopTrying = true
                }
                
            }
            
            task.resume()
            while !ready && !failed && !stopTrying {
                usleep(100000)
            }
            
            if content != nil || stopTrying {
                return content
            }
        
        }
        
        return content
    }
    
    internal func setUrl(url: String) {
        self.url = NSURL(string: url)
    }
    
    static func getInfoFromPage(page: NSString, infoSearch: String, terminator: String = "\"") -> String? {
        let position = page.rangeOfString(infoSearch)
        let location = position.location
        if location > page.length {
            return nil
        }
        let containsInfo = (page.substringToIndex(min(location + 300, page.length - 1)) as NSString).substringFromIndex(min(location + infoSearch.characters.count, page.length - 1))
        let characters = containsInfo.characters
        
        var info = ""
        for character in characters {
            let char = "\(character)"
            if char == terminator { break }
            info += char
        }
        
        return info
    }
    
    static func clearCookies() {
        let cookies = NSHTTPCookieStorage.sharedHTTPCookieStorage()
        for cookie in (cookies.cookies ?? []) {
            cookies.deleteCookie(cookie)
        }
    }
    
    
    //MARK: - HTTP Requests
    
    static func requestPageWithLoginVerification(url: String) -> HTMLDocument? {
        
        if !url.containsString("t-square") && !url.containsString("/pda/") {
            return HttpClient.contentsOfPage(url, postNotificationOnError: false)
        }
        
        guard let loginController = (UIApplication.sharedApplication().delegate as? AppDelegate)?.window?.rootViewController as? LoginViewController else { return nil }
        
        let requestedPage = HttpClient.contentsOfPage(url, postNotificationOnError: false)

        guard let contents = requestedPage?.toHTML else {
            //"Network unavailable."
            sync { loginController.syncronizedNetworkErrorRecieved(showAlert: true) }
            return nil
        }
        
        if contents.containsString("Georgia Tech :: LAWN :: Login Redirect Page") {
            
            sync { loginController.syncronizedNetworkErrorRecieved(showAlert: false) }
            
            let alert = UIAlertController(title: "Couldn't connect to T-Square", message: "Your login with GTother has expired.", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Nevermind", style: .Destructive, handler: nil))
            alert.addAction(UIAlertAction(title: "Log In", style: .Default, handler: { _ in
                UIApplication.sharedApplication().openURL(NSURL(string: "http://t2.gatech.edu")!)
            }))
            loginController.presentViewController(alert, animated: true, completion: nil)
            
            return nil
        }
        
        if !contents.containsString("Log Out")  {
            //Cookies invalid. Attempting to reauthenticate.
            
            var username: String
            var password: String
            
            if TSAuthenticatedReader == nil {
                //try to load credentials from disk
                if let (savedUsername, savedPassword) = savedCredentials() {
                    username = savedUsername
                    password = savedPassword
                } else {
                    
                    //try to pull from the login controller's text fields
                    if let typedUsername = loginController.usernameField.text,
                       let typedPassword = loginController.passwordField.text
                       where typedUsername.length > 0 && typedPassword.length > 0 {
                        username = typedUsername
                        password = typedPassword
                    }
                    
                    else {
                        //we don't have a copy of the user's credentials anymore
                        loginController.unpresentClassesView()
                        
                        let alert = UIAlertController(title: "Couldn't connect to T-Square", message: "You were automatically logged out by the server. Please log in again.", preferredStyle: .Alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                        loginController.presentViewController(alert, animated: true, completion: nil)
                        
                        return nil
                    }
                    
                }
            } else {
                username = TSAuthenticatedReader.username
                password = TSAuthenticatedReader.password
            }
            
            Authenticator.isRunningInBackground = true
            TSReader.authenticatedReader(user: username, password: password, isNewLogin: false, completion: { reader in
                Authenticator.isRunningInBackground = false
                
                if let reader = reader {
                    TSAuthenticatedReader = reader
                }
                else {
                    loginController.unpresentClassesView()
                    
                    let alert = UIAlertController(title: "Couldn't connect to T-Square", message: "Either the network connection is unavailable, or your login credentials have changed since the last time you logged in.", preferredStyle: .Alert)
                    
                    alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                    alert.addAction(UIAlertAction(title: "Settings", style: .Default, handler: { _ in openSettings() }))
                        
                    loginController.presentViewController(alert, animated: true, completion: nil)
                    TSAuthenticatedReader = nil
                }
            })
            
            return TSAuthenticatedReader != nil ? HttpClient.contentsOfPage(url, postNotificationOnError: false) : nil
        }
        else {
            return requestedPage
        }
    }
    
    static func contentsOfPage(url: String, postNotificationOnError: Bool = true) -> HTMLDocument? {
        
        let fetchURL = url.stringByReplacingOccurrencesOfString("site", withString: "pda")
        
        if postNotificationOnError {
            return requestPageWithLoginVerification(fetchURL)
        }
        
        let page = HttpClient(url: fetchURL)
        
        guard let text = page.sendGet() else { return nil }
        return Kanna.HTML(html: text as String, encoding: NSUTF8StringEncoding)
    }
    
    static func getPageForResourceFolder(resource: ResourceFolder) -> HTMLDocument? {
        if resource.collectionID == "" && resource.navRoot == "" {
            let contents = contentsOfPage(resource.link)
            if contents == nil {
                NSNotificationCenter.defaultCenter().postNotificationName(TSNetworkErrorNotification, object: nil)
            }
            return contents
        }
        
        let postString = "?source=0&criteria=title&sakai_action=doNavigate&collectionId=\(resource.collectionID.preparedForURL())&navRoot=\(resource.navRoot.preparedForURL())"
        let url = "\(resource.link)\(postString)"
        
        guard let pageText = contentsOfPage(url) else {
            NSNotificationCenter.defaultCenter().postNotificationName(TSNetworkErrorNotification, object: nil)
            return nil
        }
        return pageText
    }
    
    static func getPageWith100Count(originalLink: String) -> HTMLDocument? {
        
        let postString = "?selectPageSize=100&eventSubmit_doChange_pagesize=changepagesize"
        let url = "\(originalLink)\(postString)"
        
        guard let pageText = contentsOfPage(url) else {
            NSNotificationCenter.defaultCenter().postNotificationName(TSNetworkErrorNotification, object: nil)
            return nil
        }
        return pageText
    }
    
    /*
    POST///make active
    prefs_form=numtabs:20
    prefs_form=_id43:gtc-3248-ad8f-5f07-8d4d-aa83ebdedd48 (permanent id)
    prefs_form=prefs_form
    prefs_form:_idcl=prefs_form:remove
    prefs_form:submit=Update Preferences

    POST///make inactve
    prefs_form=numtabs:20
    prefs_form=_id35:gtc-0eff-f218-57ec-88bc-566361a0fe33 (permanent id)
    prefs_form=prefs_form
    prefs_form=_idcl:prefs_form:add
    prefs_form=submit:Update Preferences
    */
    static func markClassActive(currentClass: Class, active: Bool, atPreferencesLink link: String) {
        
        var postString = "?prefs_form:numtabs=20"
        postString += "&prefs_form:_id\(active ? 43 : 35)=\(currentClass.permanentID)"
        postString += "&prefs_form=prefs_form"
        postString += "&prefs_form:_idcl=prefs_form:\(active ? "remove" : "add")"
        postString += "&prefs_form:submit=Update%20Preferences"
        
        let finalLink = "\(link)\(postString)"
        let client = HttpClient(url: finalLink)
        //double up on requests because they get lost sometimes?
        client.sendGet()
        client.sendGet()
    }
    
}


//MARK: - Relevant Extensions

extension String {
    
    func cleansed() -> String {
        var text = self as NSString
        //cleanse text of weird formatting
        //tabs and newlines
        text = (text as NSString).stringByReplacingOccurrencesOfString("\n", withString: "")
        text = (text as NSString).stringByReplacingOccurrencesOfString("\t", withString: "")
        text = (text as NSString).stringByReplacingOccurrencesOfString("\r", withString: "")
        text = (text as NSString).stringByReplacingOccurrencesOfString("<o:p>", withString: "")
        text = (text as NSString).stringByReplacingOccurrencesOfString("</o:p>", withString: "")
        
        return (text as String).withNoTrailingWhitespace()
    }
    
    func withNoTrailingWhitespace() -> String {
        var text = self as NSString
        //leading spaces
        while text.length > 1 && text.stringAtIndex(0).isWhitespace() {
            text = text.substringFromIndex(1)
        }
        
        //trailing spaces
        while text.length > 0 && text.stringAtIndex(text.length - 1).isWhitespace() {
            text = text.substringToIndex(text.length - 1)
        }
        
        return text as String
    }
    
}

extension XMLElement {
    
    var textWithLineBreaks: String {
        //do a switch-up to preserve <br>s
        var html = self.toHTML!
        html = html.stringByReplacingOccurrencesOfString("<p>", withString: "")
        html = html.stringByReplacingOccurrencesOfString("</p>", withString: "<br>")
        html = html.stringByReplacingOccurrencesOfString("&nbsp;", withString: "")
        html = html.stringByReplacingOccurrencesOfString("\r", withString: "")
        html = html.stringByReplacingOccurrencesOfString("\n", withString: "")
        html = html.stringByReplacingOccurrencesOfString("<br>", withString: "~!@!~")
        html = html.stringByReplacingOccurrencesOfString("</br>", withString: "~!@!~")
        html = html.stringByReplacingOccurrencesOfString("<br/>", withString: "~!@!~")
        
        let element = HTML(html: html, encoding: NSUTF8StringEncoding)!
        return element.text!.stringByReplacingOccurrencesOfString("~!@!~", withString: "\n")
    }
    
}
