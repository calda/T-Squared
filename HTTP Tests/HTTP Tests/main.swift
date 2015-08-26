import Foundation

class HttpClient {
    
    private var url: NSURL!
    private var session: NSURLSession
    
    internal init(url: String) {
        self.url = NSURL(string: url)
        self.session = NSURLSession.sharedSession()
        session.configuration.HTTPShouldSetCookies = true
        session.configuration.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicy.OnlyFromMainDocumentDomain
        session.configuration.HTTPCookieStorage?.cookieAcceptPolicy = NSHTTPCookieAcceptPolicy.OnlyFromMainDocumentDomain
    }
    
    internal func sendGet() -> String {
        var ready = false
        var content: String!
        var request = NSMutableURLRequest(URL: self.url)
        
        var task = session.dataTaskWithRequest(request) {
            (data, response, error) -> Void in
            content = NSString(data: data, encoding: NSASCIIStringEncoding) as! String
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
        var request = NSMutableURLRequest(URL: self.url)
        
        request.HTTPMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.HTTPBody = params.dataUsingEncoding(NSASCIIStringEncoding, allowLossyConversion: false)
        request.HTTPShouldHandleCookies = true
        
        var task = session.dataTaskWithRequest(request) {
            (data, response, error) -> Void in
            content = NSString(data: data, encoding: NSASCIIStringEncoding) as! String
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
}

func getInfoFromPage(page: NSString, infoSearch: String) -> String {
    let position = page.rangeOfString(infoSearch)
    let location = position.location
    let containsInfo = (page.substringToIndex(location + 300) as NSString).substringFromIndex(location + count(infoSearch))
    let characters = enumerate(containsInfo)
    
    var info = ""
    for (index, character) in characters {
        let char = "\(character)"
        if char == "\"" { break }
        info += char
    }
    
    return info
}

//request the login page
let client = HttpClient(url: "https://login.gatech.edu/cas/login?service=https%3A%2F%2Ft-square.gatech.edu%2Fsakai-login-tool%2Fcontainer")
let loginScreen = client.sendGet() as NSString

//parse a jsessionid
let sessionID = getInfoFromPage(loginScreen, "<form id=\"fm1\" class=\"fm-v clearfix\" action=\"")
let LT = "LT" + getInfoFromPage(loginScreen, "value=\"LT")

println(sessionID)
println(LT)


let loginClient = HttpClient(url: "https://login.gatech.edu/\(sessionID)")
let response = loginClient.sendPost("warn=true&lt=\(LT)&execution=e1s1&_eventId=submit&submit=LOGIN&username=USER&password=PASSWORD”)
//println(response)

let cs1332 = HttpClient(url: "https://t-square.gatech.edu/portal/tool/ea448536-8d59-4a0c-bc62-cc96f12d59f9?panel=Main")
println(cs1332.sendGet())










