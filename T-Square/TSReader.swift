//
//  TSReader.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 8/27/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation
import Kanna

let TSInstallDateKey = "edu.gatech.cal.appInstallDate"
let TSLastLoadDate = "edu.gatech.cal.lastLoadDate"

class TSReader {
    
    let username: String
    let password: String
    var actuallyHasNoClasses = false
    var initialPage: HTMLDocument? = nil
    
    init(username: String, password: String, initialPage: HTMLDocument?) {
        self.username = username
        self.password = password
        self.classes = nil
        self.initialPage = initialPage
    }
    
    static func authenticatedReader(user user: String, password: String, isNewLogin: Bool, completion: (TSReader?) -> ()) {
        HttpClient.authenticateWithUsername(user, password: password, completion: { success, response in
            completion(success ? TSReader(username: user, password: password, initialPage: response) : nil)
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
        
        defer {
            if classes.count > 0 {
                Class.updateShotcutItemsForActiveClasses(classes)
            }
            self.initialPage = nil
        }
        
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
        if classes.count == 0 {
            actuallyHasNoClasses = true
        }
        return classes
    }
    
    var allClasses: [Class]?
    func getAllClasses() -> [Class] {
        
        guard let doc = HttpClient.contentsOfPage("https://t-square.gatech.edu/portal/pda/") else { return classes ?? [] }
        
        for workspaceLink in doc.css("a, link") {
            if workspaceLink["title"] != "My Workspace" { continue }
            let workspaceURL = workspaceLink["href"]!
            guard let workspace = HttpClient.contentsOfPage(workspaceURL) else { return classes ?? [] }

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
    
    func getGradesForClass(currentClass: Class) -> GradeGroup {
        let rootGroup = GradeGroup(name: "ROOT", weight: 1.0)
        
        defer {
            //load custom grades before exiting scope
            let data = NSUserDefaults.standardUserDefaults()
            var dict = data.dictionaryForKey(TSCustomGradesKey) as? [String : [String]] ?? [:]
            let classKey = TSAuthenticatedReader.username + "~" + currentClass.ID
            
            if let customGrades = dict[classKey] {
                var groups: [GradeGroup] = []
                var grades: [Grade] = []
                
                for string in customGrades {
                    if let score = scorefromString(string) {
                        if let grade = score as? Grade { grades.append(grade) }
                        if let group = score as? GradeGroup { groups.append(group) }
                    }
                }
                
                for group in groups {
                    rootGroup.scores.append(group)
                    group.owningGroup = rootGroup
                }
                
                for grade in grades {
                    let groupName = grade.owningGroupName ?? "ROOT"
                    var group: GradeGroup?
                    
                    if groupName == "ROOT" {
                        group = rootGroup
                    } else  {
                        for score in rootGroup.scores {
                            if let currentGroup = score as? GradeGroup where currentGroup.name.lowercaseString == groupName.lowercaseString {
                                group = currentGroup
                                break
                            }
                        }
                    }
                    
                    group?.scores.append(grade)
                    grade.owningGroup = group
                }
                
            }
        }
        
        guard let classPage = currentClass.getClassPage() else { return rootGroup }
        //load page for class announcements
        for link in classPage.css("a, link") {
            if link.text != "Gradebook" && link.text != "Markbook" { continue }
            guard let gradebookPage = HttpClient.contentsOfPage(link["href"]!) else { return rootGroup }
            
            
            //get indecies for name, score, weight, and comment
            var nameIndex: Int?
            var scoreIndex: Int?
            var weightIndex: Int?
            var commentIndex: Int?
            
            let thead = gradebookPage.css("thead")[0]
            let thArray = thead.css("th")
            for i in 0 ..< thArray.count {
                let text = thArray[i].text!.lowercaseString
                if text.containsString("title") { nameIndex = i }
                else if text.containsString("grade") { scoreIndex = i }
                else if text.containsString("weight") { weightIndex = i }
                else if text.containsString("comment") { commentIndex = i }
            }
            
            //load grades
            var currentGroup = rootGroup
            
            for row in gradebookPage.css("tr") {
                let cols = row.css("td")
                
                if cols.count < 3 { continue }
                
                //start of a new category
                if (cols[nameIndex ?? 1].toHTML ?? "").containsString("categoryHeading") {
                    if currentGroup !== rootGroup {
                        rootGroup.scores.append(currentGroup)
                    }
                    let name = (nameIndex != nil ? cols[nameIndex!].text?.cleansed() : nil) ?? "Unnamed Category"
                    let weight = (weightIndex != nil ? cols[weightIndex!].text?.cleansed() : nil)
                    currentGroup = GradeGroup(name: name, weight: weight)
                    currentGroup.owningGroup = rootGroup
                }
                
                //grade in the existing category
                else {
                    
                    let name = (nameIndex != nil ? cols[nameIndex!].text?.cleansed() : nil) ?? "Unnamed Assignment"
                    let score = (scoreIndex != nil ? cols[scoreIndex!].text?.cleansed() : nil) ?? "-"
                    let weight: String? = (weightIndex != nil ? cols[weightIndex!].text?.cleansed() : nil)
                    
                    var comment: String? = nil
                    if let commentIndex = commentIndex where commentIndex < cols.count {
                        comment = cols[commentIndex].text?.cleansed()
                    }
                    
                    let grade = Grade(name: name, score: score, weight: weight, comment: comment)
                    currentGroup.scores.append(grade)
                    grade.owningGroup = currentGroup
                    
                    //check if this grade has been artificially dropped by the user
                    let data = NSUserDefaults.standardUserDefaults()
                    var dict = data.dictionaryForKey(TSDroppedGradesKey) as? [String : [String]] ?? [:]
                    let classKey = TSAuthenticatedReader.username + "~" + currentClass.ID
                    let droppedClasses = dict[classKey] ?? []
                    
                    if droppedClasses.contains(grade.representAsString()) {
                        grade.contributesToAverage = false
                    }
                }
            }
            
            if currentGroup !== rootGroup {
                rootGroup.scores.append(currentGroup)
            }
        }
        
        currentClass.grades = rootGroup
        return rootGroup
    }
    
}

extension String {
    
    func dateWithTSquareFormat() -> NSDate? {
        //convert date string to NSDate
        let formatter = NSDateFormatter()
        formatter.locale = NSLocale(localeIdentifier: "en_US")
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

