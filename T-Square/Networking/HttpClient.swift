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

let TSNetworkQueue = DispatchQueue(label: "edu.gatech.cal.network-queue", attributes: DispatchQueue.Attributes.concurrent)

class HttpClient {
    
    //MARK: - HTTP implementation
    
    fileprivate var url: URL?
    fileprivate var session: URLSession
    
    internal init(url: String, useMobile: Bool = true) {
        self.url = URL(string: url)
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        if useMobile {
            config.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 8_0 like Mac OS X) AppleWebKit/600.1.3 (KHTML, like Gecko) Version/8.0 Mobile/12A4345d Safari/600.1.4"]
        }
        self.session = URLSession(configuration: config)
        URLCache.shared = SwizzlingNSURLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
        
        session.configuration.httpShouldSetCookies = true
        session.configuration.httpCookieAcceptPolicy = HTTPCookie.AcceptPolicy.always
        session.configuration.httpCookieStorage?.cookieAcceptPolicy = HTTPCookie.AcceptPolicy.always
        session.configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    }
    
    @discardableResult internal func sendGet() -> String? {
        URLCache.shared.removeAllCachedResponses()
        
        var attempts = 0
        var failed = false
        var stopTrying = false
        var ready = false
        var content: String!
        guard let url = self.url else { return nil }
        
        let request = NSMutableURLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5.0)
        
        while !stopTrying && !ready {
            
            failed = false
            
            let task = session.dataTask(with: request as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                if let data = data {
                    if let loadedContent = NSString(data: data, encoding: String.Encoding.ascii.rawValue) {
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
                
            }) 
            
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
    
    internal func setUrl(_ url: String) {
        self.url = URL(string: url)
    }
    
    static func getInfoFromPage(_ page: NSString, infoSearch: String, terminator: String = "\"") -> String? {
        let position = page.range(of: infoSearch)
        let location = position.location
        if location > page.length {
            return nil
        }
        
        let containsInfo = (page.substring(to: min(location + 300, page.length - 1)) as NSString).substring(from: min(location + infoSearch.characters.count, page.length - 1))
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
        let cookies = HTTPCookieStorage.shared
        for cookie in (cookies.cookies ?? []) {
            cookies.deleteCookie(cookie)
        }
    }
    
    
    //MARK: - HTTP Requests
    
    static func requestPageWithLoginVerification(_ url: String) -> HTMLDocument? {
        
        if !url.contains("t-square") && !url.contains("/pda/") {
            return HttpClient.contentsOfPage(url, postNotificationOnError: false)
        }
        
        guard let loginController = (UIApplication.shared.delegate as? AppDelegate)?.window?.rootViewController as? LoginViewController else { return nil }
        
        let requestedPage = HttpClient.contentsOfPage(url, postNotificationOnError: false)

        guard let contents = requestedPage?.toHTML else {
            //"Network unavailable."
            sync { loginController.syncronizedNetworkErrorRecieved(showAlert: true) }
            return nil
        }
        
        if contents.contains("Georgia Tech :: LAWN :: Login Redirect Page") {
            
            sync { loginController.syncronizedNetworkErrorRecieved(showAlert: false) }
            
            let alert = UIAlertController(title: "Couldn't connect to T-Square", message: "Your login with GTother has expired.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Nevermind", style: .destructive, handler: nil))
            alert.addAction(UIAlertAction(title: "Log In", style: .default, handler: { _ in
                UIApplication.shared.openURL(URL(string: "http://t2.gatech.edu")!)
            }))
            loginController.present(alert, animated: true, completion: nil)
            
            return nil
        }
        
        if !contents.contains("Log Out")  {
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
                       let typedPassword = loginController.passwordField.text, typedUsername.length > 0 && typedPassword.length > 0 {
                        username = typedUsername
                        password = typedPassword
                    }
                    
                    else {
                        //we don't have a copy of the user's credentials anymore
                        loginController.unpresentClassesView()
                        
                        let alert = UIAlertController(title: "Couldn't connect to T-Square", message: "You were automatically logged out by the server. Please log in again.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        loginController.present(alert, animated: true, completion: nil)
                        
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
                    
                    let alert = UIAlertController(title: "Couldn't connect to T-Square", message: "You were automatically logged out by the server. Please log in again.", preferredStyle: .alert)
                    
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in openSettings() }))
                        
                    loginController.present(alert, animated: true, completion: nil)
                    TSAuthenticatedReader = nil
                }
            })
            
            return TSAuthenticatedReader != nil ? HttpClient.contentsOfPage(url, postNotificationOnError: false) : nil
        }
        else {
            return requestedPage
        }
    }
    
    static func contentsOfPage(_ url: String, postNotificationOnError: Bool = true) -> HTMLDocument? {
        
        let fetchURL = url.replacingOccurrences(of: "site", with: "pda")
        
        if postNotificationOnError {
            return requestPageWithLoginVerification(fetchURL)
        }
        
        let page = HttpClient(url: fetchURL)
        
        guard let text = page.sendGet() else { return nil }
        
        do {
            return try Kanna.HTML(html: text as String, encoding: String.Encoding.utf8)
        } catch {
            print("cannot return content of page")
        }
        
        return nil
        
    }
    
    static func getPageForResourceFolder(_ resource: ResourceFolder) -> HTMLDocument? {
        if resource.collectionID == "" && resource.navRoot == "" {
            let contents = contentsOfPage(resource.link)
            if contents == nil {
                NotificationCenter.default.post(name: Notification.Name(rawValue: TSNetworkErrorNotification), object: nil)
            }
            return contents
        }
        
        let postString = "?source=0&criteria=title&sakai_action=doNavigate&collectionId=\(resource.collectionID.preparedForURL())&navRoot=\(resource.navRoot.preparedForURL())"
        let url = "\(resource.link)\(postString)"
        
        guard let pageText = contentsOfPage(url) else {
            NotificationCenter.default.post(name: Notification.Name(rawValue: TSNetworkErrorNotification), object: nil)
            return nil
        }
        return pageText
    }
    
    static func getPageWith100Count(_ originalLink: String) -> HTMLDocument? {
        
        let postString = "?selectPageSize=100&eventSubmit_doChange_pagesize=changepagesize"
        let url = "\(originalLink)\(postString)"
        
        guard let pageText = contentsOfPage(url) else {
            NotificationCenter.default.post(name: Notification.Name(rawValue: TSNetworkErrorNotification), object: nil)
            return nil
        }
        return pageText
    }
    
    static func markClassActive(_ currentClass: Class, active: Bool, atPreferencesLink link: String) {
        
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
        text = (text as NSString).replacingOccurrences(of: "\n", with: "") as NSString
        text = (text as NSString).replacingOccurrences(of: "\t", with: "") as NSString
        text = (text as NSString).replacingOccurrences(of: "\r", with: "") as NSString
        text = (text as NSString).replacingOccurrences(of: "<o:p>", with: "") as NSString
        text = (text as NSString).replacingOccurrences(of: "</o:p>", with: "") as NSString
        
        return (text as String).withNoTrailingWhitespace()
    }
    
    func withNoTrailingWhitespace() -> String {
        var text = self as NSString
        //leading spaces
        while text.length > 1 && text.stringAtIndex(0).isWhitespace() {
            text = text.substring(from: 1) as NSString
        }
        
        //trailing spaces
        while text.length > 0 && text.stringAtIndex(text.length - 1).isWhitespace() {
            text = text.substring(to: text.length - 1) as NSString
        }
        
        return text as String
    }
    
}

extension XMLElement {
    
    var textWithLineBreaks: String {
        //do a switch-up to preserve <br>s
        var html = self.toHTML!
        html = html.replacingOccurrences(of: "<p>", with: "")
        html = html.replacingOccurrences(of: "</p>", with: "<br>")
        html = html.replacingOccurrences(of: "&nbsp;", with: "")
        html = html.replacingOccurrences(of: "\r", with: "")
        html = html.replacingOccurrences(of: "\n", with: "")
        html = html.replacingOccurrences(of: "<br>", with: "~!@!~")
        html = html.replacingOccurrences(of: "</br>", with: "~!@!~")
        html = html.replacingOccurrences(of: "<br/>", with: "~!@!~")
        
        do {
            let element = try HTML(html: html, encoding: String.Encoding.utf8)
            return element.text!.replacingOccurrences(of: "~!@!~", with: "\n")
        } catch {
            print("fatal error in HttpClient.swift")
        }
        
        return ""
    }
    
}
