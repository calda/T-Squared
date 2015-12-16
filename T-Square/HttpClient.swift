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
    
    private var url: NSURL!
    private var session: NSURLSession
    
    internal init(url: String, useMobile: Bool = true) {
        self.url = NSURL(string: url)
        
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.requestCachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData
        if useMobile {
            config.HTTPAdditionalHeaders = ["User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 8_0 like Mac OS X) AppleWebKit/600.1.3 (KHTML, like Gecko) Version/8.0 Mobile/12A4345d Safari/600.1.4"]
        }
        self.session = NSURLSession(configuration: config)
        NSURLCache.setSharedURLCache(NSURLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil))
        
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
                
                attempts++
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
    
    internal func sendPost(params: String) -> String? {
        NSURLCache.sharedURLCache().removeAllCachedResponses()
        
        var attempts = 0
        var stopTrying = false
        var failed = false
        var ready = false
        var content: String!
        let request = NSMutableURLRequest(URL: url, cachePolicy: .ReloadIgnoringLocalCacheData, timeoutInterval: 5.0)
        
        request.HTTPMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.HTTPBody = params.dataUsingEncoding(NSASCIIStringEncoding, allowLossyConversion: false)
        //request.HTTPShouldHandleCookies = true
        
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
                
                attempts++
                failed = true
                if attempts >= 1 {
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
    
    //MARK: - Pulling data from the page
    static var sessionID: String?
    static var authFormPost: String?
    static var authLTPost: String?
    
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
    
    static var previous: String?
    static var isRunningInBackground = false
    
    static func authenticateWithUsername(var user: String, var password: String, completion: (Bool, HTMLDocument?) -> ()) {
        var didCompletion = false
        
        //call the completion before exiting scope
        defer {
            if !didCompletion {
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
        let loginScreen = loginScreenText as NSString
        
        var formPost: String
        var LT: String
        
        //get page form
        if let previousFormPost = HttpClient.authFormPost {
            formPost = previousFormPost
        }
        else if let pageFormAddress = HttpClient.getInfoFromPage(loginScreen, infoSearch: "<form id=\"fm1\" class=\"fm-v clearfix\" action=\"") {
            formPost = pageFormAddress
            HttpClient.authFormPost = formPost
        }
        else {
            return
        }
        
        //get LT
        if let previousLT = HttpClient.authLTPost {
            LT = previousLT
        }
        else if let LT_part = HttpClient.getInfoFromPage(loginScreen, infoSearch: "value=\"LT") {
            LT = "LT" + LT_part
            HttpClient.authLTPost = LT
        }
        else {
            return
        }
        
        user.prepareForURL()
        password.prepareForURL()
        
        //send HTTP POST for login
        let loginClient = HttpClient(url: "https://login.gatech.edu/\(formPost)")
        guard let response = loginClient.sendPost("warn=true&lt=\(LT)&execution=e1s1&_eventId=submit&submit=LOGIN&username=\(user)&password=\(password)") else {
            //(UIApplication.sharedApplication().windows[0].rootViewController as? LoginViewController)?.networkErrorRecieved()
            NSNotificationCenter.defaultCenter().postNotificationName(TSNetworkErrorNotification, object: nil)
            return
        }
        
        if response.containsString("Incorrect login or disabled account.") || response.containsString("Login requested by:") {
            didCompletion = true
            HttpClient.sessionID = HttpClient.getInfoFromPage(formPost, infoSearch: "jsessionid=", terminator: "?")
            sync() { completion(false, nil) }
        }
        else {
            didCompletion = true
            if isRunningInBackground {
                //Calling completion on current thread to resolve background activity
                completion(true, HTML(html: response, encoding: NSUTF8StringEncoding))
            }
            else {
                sync {
                    //Calling completion synchronously
                    completion(true, HTML(html: response, encoding: NSUTF8StringEncoding))
                }
            }
        }
    }
    
    static func contentsOfPage(url: String, postNotificationOnError: Bool = true) -> HTMLDocument? {
        let fetchURL = url.stringByReplacingOccurrencesOfString("site", withString: "pda")
        let page = HttpClient(url: fetchURL)    
        
        guard let text = page.sendGet() else {
            if postNotificationOnError {
                NSNotificationCenter.defaultCenter().postNotificationName(TSNetworkErrorNotification, object: nil)
            }
            return nil
        }
        
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
        let postString = "source=0&criteria=title&sakai_action=doNavigate&collectionId=\(resource.collectionID)&navRoot=\(resource.navRoot)"
        let client = HttpClient(url: resource.link)
        guard let pageText = client.sendPost(postString) else {
            NSNotificationCenter.defaultCenter().postNotificationName(TSNetworkErrorNotification, object: nil)
            return nil
        }
        return Kanna.HTML(html: pageText, encoding: NSUTF8StringEncoding)
    }
    
    static func getPageWith100Count(originalLink: String) -> HTMLDocument? {
        let postString = "?selectPageSize=100&eventSubmit_doChange_pagesize=changepagesize"
        let client = HttpClient(url: "\(originalLink)\(postString)")
        guard let pageText = client.sendGet() else {
            NSNotificationCenter.defaultCenter().postNotificationName(TSNetworkErrorNotification, object: nil)
            return nil
        }
        return Kanna.HTML(html: pageText, encoding: NSUTF8StringEncoding)
    }
    
    /*
    POST///make active
    prefs_form:numtabs:20
    prefs_form:_id43:gtc-3248-ad8f-5f07-8d4d-aa83ebdedd48
    prefs_form:prefs_form
    prefs_form:_idcl:prefs_form:remove
    prefs_form:submit:Update Preferences

    POST///make inactve
    prefs_form:numtabs:20
    prefs_form:_id35:gtc-0eff-f218-57ec-88bc-566361a0fe33
    prefs_form:prefs_form
    prefs_form:_idcl:prefs_form:add
    prefs_form:submit:Update Preferences
    */
    static func markClassActive(currentClass: Class, active: Bool, atPreferencesLink link: String) {
        
        var postString = "?prefs_form:numtabs=20"
        postString += "&prefs_form:_id\(active ? 43 : 35)=\(currentClass.permanentID)"
        postString += "&prefs_form=prefs_form"
        postString += "&prefs_form:_idcl=prefs_form:\(active ? "remove" : "add")"
        postString += "&prefs_form:submit=Update%20Preferences"
        
        let finalLink = "\(link)\(postString)"
        let client = HttpClient(url: finalLink)
        //double up on requests because they get lost sometimes
        client.sendGet()
        client.sendGet()
    }
    
}

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
