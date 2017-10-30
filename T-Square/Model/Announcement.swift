//
//  Announcement.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 8/28/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation
import Kanna

let TSReadAnnouncementsKey = "edu.gatech.cal.readAnnouncements"

class Announcement : CustomStringConvertible {
    
    let owningClass: Class
    let name: String
    var message: String?
    var author: String
    var date: Date?
    var rawDateString: String
    let link: String
    
    var attachments: [Attachment]?
    
    var description: String {
        return name
    }
    
    init(inClass: Class, name: String, author: String, date: String, link: String) {
        self.owningClass = inClass
        self.name = name
        self.author = author
        self.link = link
        self.rawDateString = date
        self.date = date.dateWithTSquareFormat() as Date?
    }
    
    func loadMessage(_ completion: @escaping (String) -> ()) {
        //only load if necessary
        if let message = self.message {
            completion(message)
            return
        }
        
        //load message
        TSNetworkQueue.async(execute: {
            if let page = HttpClient.contentsOfPage(self.link) {
                
                if !page.toHTML!.contains("<p>") {
                    self.loadMessage(completion)
                }
                else {
                    var message: String = ""
                    for pTag in page.css("p") {
                        message += pTag.textWithLineBreaks
                        for div in pTag.css("div") {
                            message += div.textWithLineBreaks
                        }
                    }
                    
                    for imgTag in page.css("img") {
                        if let src = imgTag["src"], src.contains("http") {
                            let attachment = Attachment(link: src, fileName: "Attached image")
                            if self.attachments == nil { self.attachments = [] }
                            self.attachments!.append(attachment)
                        }
                    }
                    
                    self.message = message.withNoTrailingWhitespace()
                    
                    //remove weird tags that sometimes end up in announcements
                    self.message = self.message!.replacingOccurrences(of: "<o:p>", with: "")
                    self.message = self.message!.replacingOccurrences(of: "</o:p>", with: "")
                    
                    //load attachments if present
                    for link in page.css("a, link") {
                        let linkURL = link["href"] ?? ""
                        if linkURL.contains("/attachment/") {
                            let attachment = Attachment(link: linkURL, fileName: link.text?.cleansed() ?? "Attached file")
                            if self.attachments == nil { self.attachments = [] }
                            self.attachments!.append(attachment)
                        }
                    }
                    
                    sync() { completion(self.message!) }
                }
                
            }
            else {
                sync() { completion("Couldn't load message.") }
            }
        })
    }
    
    func hasBeenRead() -> Bool {
        guard let date = self.date else { return true }
        let data = UserDefaults.standard
        
        //mark as read if the announcement pre-dates the install date of the app
        if let installDate = data.value(forKey: TSInstallDateKey) as? Date {
            if installDate.timeIntervalSince(date) > 0 {
                return true
            }
        }
        
        let read = data.value(forKey: TSReadAnnouncementsKey) as? [Date] ?? []
        return read.contains(date)
    }
    
    func markRead() {
        guard let date = self.date else { return }
        let data = UserDefaults.standard
        var read = data.value(forKey: TSReadAnnouncementsKey) as? [Date] ?? []
        read.insert(date, at: 0)
        data.setValue(read, forKey: TSReadAnnouncementsKey)
    }
    
}

class Attachment {
    
    let link: String?
    let fileName: String
    let rawText: String?
    
    init(link: String, fileName: String) {
        self.link = link
        self.fileName = fileName
        self.rawText = nil
    }
    
    init(fileName: String, rawText: String) {
        self.link = nil
        self.rawText = rawText
        self.fileName = fileName
    }
    
}
