//
//  TSReader.swift
//  T-Square
//
//  Created by Cal on 8/27/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import Kanna

class TSReader {
    
    static func authenticatedReader(user user: String, password: String, completion: (TSReader?) -> ()) {
        HttpClient.authenticateWithUsername(user, password: password, completion: { success in
            completion(success ? TSReader() : nil)
        })
    }
    
    
    var classes: [Class]?
    func getClasses() -> [Class] {
        
        if let classes = self.classes {
            return classes
        }
        
        guard let doc = HttpClient.contentsOfPage("https://t-square.gatech.edu/portal/pda/") else { return [] }
        
        var classes: [Class] = []
        var saveLinksAsClasses: Bool = false
        
        for link in doc.css("a, link") {
            if let rawText = link.text {
                
                let text = rawText.cleansed()
                
                //class links start after My Workspace tab
                if !saveLinksAsClasses && text == "My Workspace" {
                    saveLinksAsClasses = true
                }
                
                else if saveLinksAsClasses {
                    //find the end of the class links
                    if text == "" || text.hasPrefix("\n") || text == "Switch to Full View" {
                        break
                    }
                    
                    //show the short-form name unless there would be duplicates
                    let newClass = Class(fromElement: link)
                    for otherClass in classes {
                        if newClass.name == otherClass.name {
                            newClass.useSectionName()
                            otherClass.useSectionName()
                        }
                    }
                    classes.append(newClass)
                }
            }
        }
        
        self.classes = classes
        return classes
    }
    
    func getAnnouncementsForClass(currentClass: Class) -> [Announcement] {
        guard let classPage = currentClass.getClassPage() else { return [] }
        
        var announcements: [Announcement] = []
        
        //load page for class
        for link in classPage.css("a, link") {
            if link.text != "Announcements" { continue }
            guard let announcementsPage = HttpClient.contentsOfPage(link["href"]!) else { return [] }
            
            //load announcements
            for row in announcementsPage.css("tr") {
                let links = row.css("a")
                if links.count == 1 {
                    
                    let link = links[0]["href"]!
                    let name = links[0].text!.cleansed()
                    var author: String = ""
                    var date: String = ""
                    
                    for col in row.css("td") {
                        if let header = col["headers"] {
                            let text = col.text!.cleansed()
                            switch(header) {
                                case "author": author = text; break;
                                case "date": date = text; break;
                                default: break;
                            }
                        }
                    }
                    
                    let announcement = Announcement(inClass: currentClass, name: name, author: author, date: date, link: link)
                    announcements.append(announcement)
                }
            }
            
            print(announcements)
            return announcements
        }
        
        return announcements
    }
    
}