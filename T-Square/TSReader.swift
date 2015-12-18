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
    
    //MARK: - Creating the TSAuthenticatedReader
    
    let username: String
    let password: String
    var initialPage: HTMLDocument? = nil
    var actuallyHasNoClasses = false
    
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
    
    //MARK: - Loading Classes
    
    var classes: [Class]?
    func getActiveClasses() -> [Class] {
        
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
                    newClass.isActive = true
                    for otherClass in classes {
                        if otherClass.name.hasPrefix(newClass.name) {
                            newClass.useFullName()
                            otherClass.useFullName()
                        }
                    }
                    classes.append(newClass)
                }
            }
        }
        
        self.classes = classes
        return classes
    }
    
    func checkIfHasNoClasses() {
        
        //the thought process here is that the list of classes goes between "My Workspace" and "Switch to Full View".
        //if those two are sequential, then there are no classes.
        
        guard let doc = initialPage ?? HttpClient.contentsOfPage("https://t-square.gatech.edu/portal/pda/") else { return }
        let links = doc.css("a, link")
        let count = links.count
        let anchorLinks = [
            ("Log Out", count - 3),
            ("My Workspace", count - 2),
            //classes normally go here
            ("Switch to Full View", count - 1)
        ]
        
        var hasClasses = false
        
        for (text, index) in anchorLinks {
            if index < 0 {
                hasClasses = true
                break
            }
            
            let actual = links[index].text?.cleansed() ?? ""
            if text != actual {
                hasClasses = true
                break
            }
        }
        
        self.actuallyHasNoClasses = !hasClasses
    }
    
    var allClassesCached: (classes: [Class], preferencesLink: String?)?
    func getAllClasses() -> (classes: [Class], preferencesLink: String?) {
        
        guard let doc = HttpClient.contentsOfPage("https://t-square.gatech.edu/portal/pda/") else { return (classes ?? [], nil) }
        
        for workspaceLink in doc.css("a, link") {
            if workspaceLink["title"] != "My Workspace" { continue }
            let workspaceURL = workspaceLink["href"]!
            
            guard let workspace = HttpClient.contentsOfPage(workspaceURL) else { return (classes ?? [], nil) }

            for worksiteLink in workspace.css("a, link") {
                if worksiteLink["title"] != "Worksite Setup" { continue }
                let worksiteURL = worksiteLink["href"]!.stringByReplacingOccurrencesOfString("tool-reset", withString: "tool")
                
                //find preferencesLink
                var preferencesLink: String?
                for link in workspace.css("a, link") {
                    if link["title"] != "Preferences" { continue }
                    if let mainPreferencesLink = link["href"],
                       //pull from the page's form
                       let mainPreferencesPage = HttpClient.contentsOfPage(mainPreferencesLink) {
                        
                        let forms = mainPreferencesPage.css("form")
                        if forms.count > 0 {
                            preferencesLink = forms[0]["action"]?.stringByReplacingOccurrencesOfString("/tool-reset/", withString: "/tool/")
                        }
                    }
                }
                
                guard let worksite = HttpClient.getPageWith100Count(worksiteURL) else { return (classes ?? [], preferencesLink) }
                
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
                            newClass.useFullName()
                            otherClass.useFullName()
                        }
                    }
                    
                    //check if this class is an active class
                    if self.classes == nil { self.getActiveClasses() }
                    if let activeClasses = self.classes where activeClasses.contains(newClass) {
                        newClass.isActive = true
                    }
                    
                    allClasses.append(newClass)
                    
                    //kick off the process to download the class's specific subject name
                    dispatch_async(TSNetworkQueue) {
                        newClass.pullSpecificSubjectNameIfNotCached()
                    }
                }
                
                self.allClassesCached = (allClasses, preferencesLink)
                return (allClasses, preferencesLink)
            }
        }
        
        return (classes ?? [], nil)
    }
    
    func getSpecificSubjectNameForClass(currentClass: Class) -> String? {
        guard let classPage = currentClass.getClassPage() else { return nil }
        
        //load page for class information display
        for link in classPage.css("a, link") {
            if link.text != "Site Information Display" { continue }
            
            let url = link["href"]!
            guard let page = HttpClient.contentsOfPage(url) else { return nil }
            
            for div in page.css("div") {
                if div["class"]?.containsString("siteDescription") == true {
                    let text = div.text?.stringByReplacingOccurrencesOfString("\n", withString: " ").cleansed()
                    
                    //sometimes there's a paragraph of text instead of just the subject name
                    //try to filter those out
                    let wordCount = text?.componentsSeparatedByString(" ").count ?? 0
                    if wordCount >= 10 {
                        return nil
                    }
                    
                    if text?.containsString("--NO TITLE--") == true {
                        return nil
                    }
                    
                    if text?.lowercaseString.containsString("welcome") == true {
                        return nil
                    }
                    
                    return text
                }
            }
        }
        
        return nil
    }
    
    //MARK: - Loading Announcements
    
    func getAnnouncementsForClass(currentClass: Class, loadAll: Bool = false) -> [Announcement] {
        guard let classPage = currentClass.getClassPage() else { return [] }
        
        var announcements: [Announcement] = []
        
        //load page for class announcements
        for link in classPage.css("a, link") {
            if link.text != "Announcements" { continue }
            
            let announcementsURL = link["href"]!
            var announcementsPageOpt: HTMLDocument?
            if !loadAll {
                announcementsPageOpt = HttpClient.contentsOfPage(announcementsURL)
            }
            else {
                announcementsPageOpt = HttpClient.getPageWith100Count(announcementsURL)
            }
            
            guard let announcementsPage = announcementsPageOpt else { return [] }
            
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
    
    //MARK: - Loading Resources
    
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
    
    //MARK: - Loading Assignments
    
    func getAssignmentsForClass(currentClass: Class) -> [Assignment] {
        guard let classPage = currentClass.getClassPage() else { return [] }
        
        var assignments: [Assignment] = []
        
        //load page for class announcements
        for link in classPage.css("a, link") {
            if link.text != "Assignments" { continue }
            guard let assignmentsPage = HttpClient.getPageWith100Count(link["href"]!) else { return [] }
            
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
    
    //MARK: - Loading Grades
    
    func getGradesForClass(currentClass: Class) -> GradeGroup {
        let rootGroup = GradeGroup(name: "ROOT", weight: 1.0)
        
        defer {
            //load custom grades before exiting scope
            let (customGrades, customGroups) = getGradesAtKey(TSCustomGradesKey, inClass: currentClass)
            addFlatGradeListToRoot(rootGroup, inClass: currentClass, groups: customGroups, grades: customGrades)
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
            
            let theads = gradebookPage.css("thead")
            if theads.count < 1 { return rootGroup }
            let thead = theads[0]
            
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
                    
                    //check if the group has an intrinsic grade
                    if let scoreIndex = scoreIndex where scoreIndex < cols.count {
                        let possibleGrade = cols[scoreIndex].text ?? "-"
                        //reuse parsing code within Grade.swift
                        let parsedGrade = Grade(name: "parser", score: possibleGrade, weight: nil, comment: nil)
                        if let intrinsicGrade = parsedGrade.score {
                            currentGroup.intrinsicScore = intrinsicGrade
                        }
                    }
                    
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
                    grade.performDropCheckWithClass(currentClass)
                }
            }
            
            if currentGroup !== rootGroup {
                rootGroup.scores.append(currentGroup)
            }
        }
        
        currentClass.grades = rootGroup.asRootGroupForClass(currentClass)
        cacheGradesForClass(currentClass, rootGroup: rootGroup)
        return rootGroup
    }
    
    func classHasCachedGrades(currentClass: Class) -> Bool {
        let data = NSUserDefaults.standardUserDefaults()
        let dict = data.dictionaryForKey(TSCachedGradesKey) as? [String : [String]] ?? [:]
        let classKey = TSAuthenticatedReader.username + "~" + currentClass.permanentID
        return dict[classKey] != nil
    }
    
    func getCachedGradesForClass(currentClass: Class) -> GradeGroup {
        let rootGroup = GradeGroup(name: "ROOT", weight: 1.0).asRootGroupForClass(currentClass)
        
        //load cached
        let (cachedGrades, cachedGroups) = getGradesAtKey(TSCachedGradesKey, inClass: currentClass)
        addFlatGradeListToRoot(rootGroup, inClass: currentClass, groups: cachedGroups, grades: cachedGrades)
        //load cutsom
        let (customGrades, customGroups) = getGradesAtKey(TSCustomGradesKey, inClass: currentClass)
        addFlatGradeListToRoot(rootGroup, inClass: currentClass, groups: customGroups, grades: customGrades)
        
        return rootGroup
    }
    
    func cacheGradesForClass(currentClass: Class, rootGroup: GradeGroup) {
        var gradesToCache: [String] = []
        
        for score in rootGroup.scores {
            
            if let grade = score as? Grade where !grade.isArtificial {
                gradesToCache.append(grade.representAsString())
            }
            if let group = score as? GradeGroup where !group.isArtificial {
                gradesToCache.append(group.representAsString())
                
                for grade in group.scores where grade is Grade && !grade.isArtificial {
                    gradesToCache.append(grade.representAsString())
                }
            }
        }
        
        let data = NSUserDefaults.standardUserDefaults()
        var dict = data.dictionaryForKey(TSCachedGradesKey) as? [String : [String]] ?? [:]
        let classKey = TSAuthenticatedReader.username + "~" + currentClass.permanentID
        
        dict[classKey] = gradesToCache
        data.setValue(dict, forKey: TSCachedGradesKey)
    }
    
    func getGradesAtKey(key: String, inClass currentClass: Class) -> (grades: [Grade], groups: [GradeGroup]) {
        let data = NSUserDefaults.standardUserDefaults()
        let dict = data.dictionaryForKey(key) as? [String : [String]] ?? [:]
        let classKey = TSAuthenticatedReader.username + "~" + currentClass.permanentID
        
        if let customGrades = dict[classKey] {
            var groups: [GradeGroup] = []
            var grades: [Grade] = []
            
            for string in customGrades {
                if let score = scorefromString(string, isArtificial: key == TSCustomGradesKey) {
                    if let grade = score as? Grade { grades.append(grade) }
                    if let group = score as? GradeGroup { groups.append(group) }
                }
            }
            
            return (grades, groups)
        }
        
        return ([], [])
    }
    
    func addFlatGradeListToRoot(rootGroup: GradeGroup, inClass currentClass: Class, groups: [GradeGroup], grades: [Grade]) {
        
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
            grade.performDropCheckWithClass(currentClass)
        }
        
    }
    
    //MARK: - Getting Resource for Syllabus
    
    func getSyllabusURLForClass(currentClass: Class) -> (rawSyllabusLink: String?, document: String?) {
        
        guard let classPage = currentClass.getClassPage() else { return (nil, nil) }
        //load page for class announcements
        for link in classPage.css("a, link") {
            if link.text != "Syllabus" { continue }
            let syllabusLink = link["href"]!
            guard let syllabusPage = HttpClient.contentsOfPage(syllabusLink) else { return (nil, nil) }
            
            //check if the syllabus is hiding in an iframe
            let iframes = syllabusPage.css("iframe")
            if iframes.count > 0 {
                let iframe = iframes[0]
                if let src = iframe["src"] {
                    return (syllabusLink, src)
                }
            }
            
            let ignore = ["Sites", "?", "Log Out", "Switch to Full View", "", currentClass.fullName]
            var notIgnore: XMLElement? = nil
            
            for link in syllabusPage.css("a") {
                if let linkText = link.text?.cleansed() where !ignore.contains(linkText) {
                    //not a link to ignore
                    if notIgnore == nil { notIgnore = link }
                    else { return (syllabusLink, nil) } //multiple links worth keeping, won't pick and choose
                }
            }
            return (syllabusLink, notIgnore?["href"])
        }
        return (nil, nil)
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

