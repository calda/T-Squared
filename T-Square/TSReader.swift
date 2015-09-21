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
let TSLastLoadDate = "edu.gatech.cal.lastLoadDate"

class TSReader {
    
    let username: String
    var initialPage: HTMLDocument? = nil
    
    init(username: String, initialPage: HTMLDocument?) {
        self.username = username
        self.classes = nil
        self.initialPage = initialPage
    }
    
    static func authenticatedReader(user user: String, password: String, isNewLogin: Bool, completion: (TSReader?) -> ()) {
        HttpClient.authenticateWithUsername(user, password: password, completion: { success, response in
            completion(success ? TSReader(username: user, initialPage: response) : nil)
        })
        
        //check if this is first time logging in
        let data = NSUserDefaults.standardUserDefaults()
        if data.valueForKey(TSInstallDateKey) == nil || isNewLogin {
            data.setValue(NSDate(), forKey: TSInstallDateKey)
        }
    }
    
    
    var classes: [Class]?
    func getClasses() -> [Class] {
        
        guard let doc = initialPage ?? HttpClient.contentsOfPage("https://t-square.gatech.edu/portal/pda/") else {
            initialPage = nil
            return []
        }
        
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
                        if otherClass.name.hasPrefix(newClass.name) {
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
    
    var allClasses: [Class]?
    func getAllClasses() -> [Class] {
        
        guard let doc = HttpClient.contentsOfPage("https://t-square.gatech.edu/portal/pda/") else { return classes ?? [] }
        
        for workspaceLink in doc.css("a, link") {
            if workspaceLink["title"] != "My Workspace" { continue }
            let workspaceURL = workspaceLink["href"]!
            guard let workspace = HttpClient.contentsOfPage(workspaceURL) else { return classes ?? [] }
            print(workspace.toHTML)
            for worksiteLink in workspace.css("a, link") {
                if worksiteLink["title"] != "Worksite Setup" { continue }
                let worksiteURL = worksiteLink["href"]!
                guard let worksite = HttpClient.contentsOfPage(worksiteURL) else { return classes ?? [] }
                
                var allClasses: [Class] = []
                
                for header in worksite.css("h4") {
                    let links = header.css("a, link")
                    if links.count == 0 { continue }
                    let classLink = links[links.count - 1]
                    
                    let className = classLink.text!.cleansed()
                    if className == "My Workspace" { continue }
                    
                    //show the short-form name unless there would be duplicates
                    let newClass = Class(fromElement: classLink)
                    for otherClass in allClasses {
                        if otherClass.name.hasPrefix(newClass.name) {
                            newClass.useSectionName()
                            otherClass.useSectionName()
                        }
                    }
                    allClasses.append(newClass)
                }
                
                self.allClasses = allClasses
                return allClasses
            }
        }
        
        return classes ?? []
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
    
    func getResourceRootForClass(currentClass: Class) -> ResourceFolder? {
        
        if let root = currentClass.rootResource {
            return root
        }
        
        guard let classPage = currentClass.getClassPage() else { return nil }
        //load page for resources
        for link in classPage.css("a, link") {
            if link.text != "Resources" { continue }
            let root = ResourceFolder(name: "Resources in \(currentClass.name)", link: link["href"]!, collectionID: "", navRoot: "")
            currentClass.rootResource = root
            return root
        }
        
        return nil
    }
    
    func getResourcesInFolder(folder: ResourceFolder) -> [Resource] {
        var resources: [Resource] = []
        //load resources if they haven't been already
        guard let resourcesPage = HttpClient.getPageForResourceFolder(folder) else { return resources }
        
        for row in resourcesPage.css("h4") {
            let links = row.css("a")
            if links.count == 0 { continue }
            var resourcesLink = links[links.count - 1]
            
            if let javascript = resourcesLink["onclick"] {
                let collectionID = HttpClient.getInfoFromPage(javascript as NSString, infoSearch: "'collectionId').value='", terminator: "'")!
                let navRoot = HttpClient.getInfoFromPage(javascript as NSString, infoSearch: "'navRoot').value='", terminator: "'")!
                let name = resourcesLink.text!.cleansed()
                let folder = ResourceFolder(name: name, link: folder.link, collectionID: collectionID, navRoot: navRoot)
                resources.append(folder)
            }
            else {
                //find a link with actual content
                var linkOffset = 2
                while resourcesLink["href"]! == "#" && linkOffset < (links.count + 1) {
                    resourcesLink = links[max(0, links.count - linkOffset)]
                    linkOffset++
                }
                
                //we didn't find anything useful. bail out.
                if resourcesLink["href"]! == "#" { continue }
                
                let resource = Resource(name: resourcesLink.text!.cleansed(), link: resourcesLink["href"]!)
                resources.append(resource)
            }
            
        }
        
        folder.resourcesInFolder = resources
        return resources
    }
    
    func getAssignmentsForClass(currentClass: Class) -> [Assignment] {
        guard let classPage = currentClass.getClassPage() else { return [] }
        
        var assignments: [Assignment] = []
        
        //load page for class announcements
        for link in classPage.css("a, link") {
            if link.text != "Assignments" { continue }
            guard let assignmentsPage = HttpClient.contentsOfPage(link["href"]!) else { return [] }
            
            //load announcements
            for row in assignmentsPage.css("tr") {
                let links = row.css("a")
                if links.count == 1 {
                    
                    let link = links[0]["href"]!
                    let name = links[0].text!.cleansed()
                    var statusString: String = ""
                    var dueDateString: String = ""
                    
                    for col in row.css("td") {
                        if let header = col["headers"] {
                            let text = col.text!.cleansed()
                            switch(header) {
                                case "dueDate": dueDateString = text; break;
                                case "status": statusString = text; break;
                                default: break;
                            }
                        }
                    }
                    
                    let complete = statusString != "Not Started" && statusString != ""
                    let assignment = Assignment(name: name, link: link, dueDate: dueDateString, completed: complete, inClass: currentClass)
                    assignments.append(assignment)
                }
            }
            currentClass.assignments = assignments
            return assignments
        }
        
        return assignments
    }
    
}

extension String {
    
    func dateWithTSquareFormat() -> NSDate? {
        //convert date string to NSDate
        let formatter = NSDateFormatter()
        formatter.dateStyle = .MediumStyle
        formatter.timeStyle = .ShortStyle
        //correct formatting to match required style
        //(Aug 27, 2015 11:27 am) -> (Aug 27, 2015, 11:27 AM)
        var dateString = self.stringByReplacingOccurrencesOfString("pm", withString: "PM")
        dateString = dateString.stringByReplacingOccurrencesOfString("am", withString: "AM")
        
        for year in 1990...2040 { //add comma after years
            dateString = dateString.stringByReplacingOccurrencesOfString("\(year) ", withString: "\(year), ")
        }
        return formatter.dateFromString(dateString)
    }
    
}

