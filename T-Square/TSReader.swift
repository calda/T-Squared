//
//  TSReader.swift
//  T-Square
//
//  Created by Cal on 8/27/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import Kanna

let TSInstallDateKey = "edu.gatech.cal.appInstallDate"

class TSReader {
    
    static func authenticatedReader(user user: String, password: String, completion: (TSReader?) -> ()) {
        HttpClient.authenticateWithUsername(user, password: password, completion: { success in
            completion(success ? TSReader() : nil)
        })
        
        //check if this is first time logging in
        let data = NSUserDefaults.standardUserDefaults()
        if data.valueForKey(TSInstallDateKey) == nil {
            data.setValue(NSDate(), forKey: TSInstallDateKey)
        }
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
        
        //load page for class announcements
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
            
            currentClass.announcements = announcements
            return announcements
        }
        
        return announcements
    }
    
    func getResourcesInRoot(currentClass: Class) -> [Resource] {
        if let root = getResourceRootForClass(currentClass) {
            return getResourcesInFolder(root)
        }
        return []
    }
    
    func getResourceRootForClass(currentClass: Class) -> Resource? {
        guard let classPage = currentClass.getClassPage() else { return nil }
        
        //load page for resources
        for link in classPage.css("a, link") {
            if link.text != "Resources" { continue }
            return Resource(name: "Resources Folder", link: link["href"]!)
        }
        
        return nil
    }
    
    func getResourcesInFolder(resource: Resource) -> [Resource] {
        if let resources = resource.resourcesInFolder where resource.isFolder {
            return resources
        }
        
        var resources: [Resource] = []
        //load resources if they haven't been already
        guard let resourcesPage = HttpClient.contentsOfPage(resource.link) else { return resources }
        
        for row in resourcesPage.css("h4") {
            let links = row.css("a")
            if links.count == 0 { continue }
            let resourcesLink = links[links.count - 1]
            
            let name = resourcesLink.text!.cleansed()
            var resourceLink = resourcesLink["href"]!
            
            if let javascript = resourcesLink["onclick"] where resourceLink == "#" {
                let splits = javascript.componentsSeparatedByString("'")
                let linkID = splits[7]
                print(linkID)
            }
            
            let resource = Resource(name: name, link: resourceLink)
            resources.append(resource)
            print(resource.name)
        }
        
        return resources
    }
    
}


