//
//  Announcement.swift
//  T-Square
//
//  Created by Cal on 8/28/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import Kanna

let TSReadAnnouncementsKey = "edu.gatech.cal.readAnnouncements"

class Announcement : CustomStringConvertible {
    
    let owningClass: Class
    let name: String
    var message: String?
    var author: String
    var date: NSDate?
    var rawDateString: String
    let link: String
    
    var description: String {
        return name
    }
    
    init(inClass: Class, name: String, author: String, date: String, link: String) {
        self.owningClass = inClass
        self.name = name
        self.author = author
        self.link = link
        self.rawDateString = date
        
        //convert date string to NSDate
        let formatter = NSDateFormatter()
        formatter.dateStyle = .MediumStyle
        formatter.timeStyle = .ShortStyle
        //correct formatting to match required style
        //(Aug 27, 2015 11:27 am) -> (Aug 27, 2015, 11:27 AM)
        var dateString = date.stringByReplacingOccurrencesOfString("pm", withString: "PM")
        dateString = dateString.stringByReplacingOccurrencesOfString("am", withString: "AM")
        
        for year in 1990...2040 { //add comma after years
            dateString = dateString.stringByReplacingOccurrencesOfString("\(year) ", withString: "\(year), ")
        }
        self.date = formatter.dateFromString(dateString)
    }
    
    func loadMessage(completion: (String) -> ()) {
        //only load if necessary
        if let message = self.message {
            completion(message)
            return
        }
        
        //load message
        dispatch_async(TSNetworkQueue, {
            if let page = HttpClient.contentsOfPage(self.link) {
                
                let messageTag = page.css("p")[0]
                self.message = messageTag.text!.cleansed().cleansed()
                sync() { completion(self.message!) }
                
            }
            else {
                sync() { completion("Couldn't load message.") }
            }
        })
    }
    
    func hasBeenRead() -> Bool {
        guard let date = self.date else { return false }
        let data = NSUserDefaults.standardUserDefaults()
        
        //mark as read if the announcement pre-dates the install date of the app
        if let installDate = data.valueForKey(TSInstallDateKey) as? NSDate {
            let now = NSDate()
            if installDate.timeIntervalSinceDate(now) < 0 {
                return true
            }
        }
        
        guard let read = data.valueForKey(TSReadAnnouncementsKey) as? [NSDate] else { return false }
        return read.contains(date)
    }
    
    func markRead() {
        let data = NSUserDefaults.standardUserDefaults()
        var read = data.valueForKey(TSReadAnnouncementsKey) as? [NSDate] ?? []
        let now = NSDate()
        read.insert(now, atIndex: 0)
        data.setValue(read, forKey: TSReadAnnouncementsKey)
    }
    
}