//
//  HttpClient.swift
//  T-Square
//
//  Created by Cal on 8/26/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import Kanna

let TSNetworkQueue = dispatch_queue_create("edu.gatech.cal.network-queue", DISPATCH_QUEUE_CONCURRENT)

class HttpClient {
    
    //MARK: - HTTP implementation
    
    private var url: NSURL!
    private var session: NSURLSession
    
    internal init(url: String) {
        self.url = NSURL(string: url)
        
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.requestCachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData
        self.session = NSURLSession(configuration: config)
        NSURLCache.setSharedURLCache(NSURLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil))
        
        session.configuration.HTTPShouldSetCookies = false
        session.configuration.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicy.OnlyFromMainDocumentDomain
        session.configuration.HTTPCookieStorage?.cookieAcceptPolicy = NSHTTPCookieAcceptPolicy.OnlyFromMainDocumentDomain
    }
    
    internal func sendGet() -> String {
        var ready = false
        var content: String!
        let request = NSMutableURLRequest(URL: self.url)
        request.cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData
        
        let task = session.dataTaskWithRequest(request) {
            (data, response, error) -> Void in
            content = NSString(data: data!, encoding: NSASCIIStringEncoding) as! String
            ready = true
        }
        task.resume()
        while !ready {
            usleep(10)
        }
        if content != nil {
            return content
        } else {
            return ""
        }
    }
    
    internal func sendPost(params: String) -> String {
        var ready = false
        var content: String!
        let request = NSMutableURLRequest(URL: self.url)
        request.cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData
        
        request.HTTPMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.HTTPBody = params.dataUsingEncoding(NSASCIIStringEncoding, allowLossyConversion: false)
        request.HTTPShouldHandleCookies = true
        
        let task = session.dataTaskWithRequest(request) {
            (data, response, error) -> Void in
            content = NSString(data: data!, encoding: NSASCIIStringEncoding) as! String
            ready = true
        }
        task.resume()
        while !ready {
            usleep(10)
        }
        if content != nil {
            return content
        } else {
            return ""
        }
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
    
    static func authenticateWithUsername(user: String, password: String, completion: (Bool) -> ()) {
        var didCompletion = false
        
        //request the login page
        let client = HttpClient(url: "https://login.gatech.edu/cas/login?service=https%3A%2F%2Ft-square.gatech.edu%2Fsakai-login-tool%2Fcontainer")
        let loginScreen = client.sendGet() as NSString
        
        defer {
            if !didCompletion {
                print("login failed, already logged in I think?")
                sync() { completion(true) }
            }
        }
        
        //print(loginScreen)
        //parse a jsessionid
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
        
        let loginClient = HttpClient(url: "https://login.gatech.edu/\(formPost)")
        let response = loginClient.sendPost("warn=true&lt=\(LT)&execution=e1s1&_eventId=submit&submit=LOGIN&username=\(user)&password=\(password)") as NSString
        //print("warn=true&lt=\(LT)&execution=e1s1&_eventId=submit&submit=LOGIN&username=\(user)&password=\(password)")
        //print("to https://login.gatech.edu/\(formPost)")
        //print(response)
        //print("SPLIT")
        
        if response.containsString("Incorrect login or disabled account.") || response.containsString("Login requested by:") {
            didCompletion = true
            HttpClient.sessionID = HttpClient.getInfoFromPage(formPost, infoSearch: "jsessionid=", terminator: "?")
            sync() { completion(false) }
        }
        else {
            didCompletion = true
            sync() { completion(true) }
        }
    }
    
    static func contentsOfPage(url: String) -> HTMLDocument {
        let page = HttpClient(url: url)
        let string = page.sendGet()
        return Kanna.HTML(html: string, encoding: NSUTF8StringEncoding)!
    }
    
}











