//
//  Class.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 8/27/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation
import UIKit
import Kanna

let TSClassOpenCountKey = "edu.gatech.cal.classOpenCount"

func == (lhs: Class, rhs: Class) -> Bool {
    return lhs.permanentID == rhs.permanentID
}

class Class : CustomStringConvertible, Equatable {
    
    let permanentID: String
    let fullName: String
    let subjectID: String?
    let subjectName: String?
    let subjectIcon: String
    var name: String
    let link: String
    var isActive: Bool = false
    
    var classPage: HTMLDocument?
    var announcements: [Announcement] = []
    var rootResource: ResourceFolder?
    var assignments: [Assignment]?
    var grades: GradeGroup?
    
    var description: String {
        return name
    }
    
    convenience init(fromElement element: XMLElement) {
        let fullName = element.text!.cleansed()
        let link = element["href"]!.stringByReplacingOccurrencesOfString("site", withString: "pda")
        self.init(withFullName: fullName, link: link)
    }
    
    init(withFullName fullName: String, link: String, displayName: String? = nil) {
        self.fullName = fullName
        self.link = link
        self.permanentID = link.componentsSeparatedByString("/").last ?? fullName
        
        //create user-facing name
        let nameParts = fullName.componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "- "))
        if nameParts.count >= 2 {
            
            if let displayName = displayName {
                self.name = displayName
            } else {
               self.name = nameParts[0] + " " + nameParts[1]
            }
            
            self.subjectID = nameParts[0]
            
            let subjectInfo = GTSubjects[nameParts[0]]
            self.subjectName = subjectInfo?.description
            self.subjectIcon = subjectInfo != nil ? "class-" + subjectInfo!.image : "class-language"
        }
        else {
            self.name = displayName ?? fullName
            let nsname = name as NSString
            
            //attempt to find the subject name from the first few characters
            for i in 1...min(5,nsname.length) {
                let substring = nsname.substringToIndex(i)
                if let subjectInfo = GTSubjects[substring] {
                    self.subjectID = substring
                    self.subjectName = subjectInfo.description
                    self.subjectIcon = "class-" + subjectInfo.image
                    return
                }
            }
            
            self.subjectID = nil
            self.subjectName = nil
            self.subjectIcon = "class-language"
        }
        
        verifySingleSubjectName()
        offsetOpenCount(0)
    }
    
    func verifySingleSubjectName() {
        if let subjectID = subjectID where (fullName as NSString).countOccurancesOfString(subjectID) > 1 {
            var subs: [String] = []
            
            let subNames = fullName.componentsSeparatedByString(" ")
            for sub in subNames {
                let nameParts = sub.componentsSeparatedByString("-")
                if nameParts.count >= 2 {
                    let new = nameParts[0] + " " + nameParts[1]
                    if !subs.contains(new) {
                        subs.append(new)
                    }
                }
            }
            
            if subs.count > 0 {
                var newName = ""
                for i in 0 ..< subs.count {
                    newName += subs[i]
                    newName += (i != (subs.count - 1) ? " / " : "")
                }
                self.name = newName
            }
        }
        
    }
    
    func useFullName() {
        self.name = (fullName as NSString).stringByReplacingOccurrencesOfString("-", withString: " ")
        offsetOpenCount(0)
    }
    
    func getClassPage() ->  HTMLDocument? {
        if let classPage = self.classPage { return classPage }
        classPage = HttpClient.contentsOfPage(self.link)
        return classPage
    }
    
    //MARK: - Tracking for 3D Touch Shortcut items
    
    func markClassOpened() {
        offsetOpenCount(1)
    }
    
    private func offsetOpenCount(offset: Int) {
        
        //update open count on disk
        let data = NSUserDefaults.standardUserDefaults()
        var dict: [String : Int] = data.dictionaryForKey(TSClassOpenCountKey) as? [String : Int] ?? [:]
        let key = "\(self.fullName)~~\(self.subjectIcon)~~\(self.name)~~\(self.link)"
        var previousCount = dict[key] ?? 0
        
        
        for otherKey in dict.keys {
            //remove any duplicates from a name change out of my control
            if otherKey.containsString(self.link) && otherKey != key {
                let otherCount = dict[otherKey]!
                previousCount += otherCount
                
                dict.removeValueForKey(otherKey)
            }
        }
        
        dict.updateValue(previousCount + offset, forKey: key)
        data.setValue(dict, forKey: TSClassOpenCountKey)
        
        Class.updateShortcutItems()
    }
    
    static func updateShotcutItemsForActiveClasses(classes: [Class]) {
        let activeClassLinks: [String] = classes.map({ return $0.link })
        
        let data = NSUserDefaults.standardUserDefaults()
        var dict: [String : Int] = data.dictionaryForKey(TSClassOpenCountKey) as? [String : Int] ?? [:]
        
        for (key, _) in dict {
            let link = key.componentsSeparatedByString("~~")[3]
            if !activeClassLinks.contains(link) {
                dict.removeValueForKey(key)
            }
        }
        
        data.setValue(dict, forKey: TSClassOpenCountKey)
        
        updateShortcutItems()
    }
    
    static func updateShortcutItems() {
        //update Shortcut Items list
        if #available(iOS 9.0, *) {
            let data = NSUserDefaults.standardUserDefaults()
            let dict: [String : Int] = data.dictionaryForKey(TSClassOpenCountKey) as? [String : Int] ?? [:]
            let sorted = dict.sort{ $0.1 > $1.1 }
            var shortcuts: [UIApplicationShortcutItem] = []
            
            for i in 0 ..< min(4, sorted.count) {
                
                let (key, _) = sorted[i]
                let splits = key.componentsSeparatedByString("~~")
                
                if splits.count != 4 { continue }
                let fullName = splits[0] //currently don't actually use the ID since it is also saved as part of the link itself
                let icon = splits[1]
                let name = splits[2]
                let link = splits[3]
                
                let shortcutIcon = UIApplicationShortcutIcon(templateImageName: icon)
                let info = ["URL" : link, "FULL_NAME" : fullName, "DISPLAY_NAME" : name]
                let shortcut = UIApplicationShortcutItem(type: "openClass", localizedTitle: name, localizedSubtitle: nil, icon: shortcutIcon, userInfo: info)
                shortcuts.append(shortcut)
            }
            
            UIApplication.sharedApplication().shortcutItems = shortcuts
        }
    }
    
}

let GTSubjects: [String : (description: String, image: String)] = [
    "ACCT" : ("Accounting", "accounting"),
    "AE" : ("Aerospace Engineering", "space"),
    "AS" : ("Air Force Aerospace Studies", "space"),
    "APPH" : ("Applied Physiology", "science"),
    "ASE" : ("Applied Systems Engineering", "engineering"),
    "ARBC" : ("Arabic", "language"),
    "ARCH" : ("Architecture", "architecture"),
    "BIOL" : ("Biology", "science"),
    "BMEJ" : ("Biomed Engineering/Joint Emory PKU", "science"),
    "BMED" : ("Biomedical Engineering", "science"),
    "BMEM" : ("Biomedical Engineering/Joint Emory", "science"),
    "BC" : ("Building Construction", "architecture"),
    "CETL" : ("Center Enhancement Teach/Learn", "world"),
    "CHBE" : ("Chemical & Biomolecular Engr", "science"),
    "CHEM" : ("Chemistry", "science"),
    "CHIN" : ("Chinese", "language"),
    "CP" : ("City Planning", "architecture"),
    "CEE" : ("Civil and Environmental Engineering", "architecture"),
    "COA" : ("College of Architecture", "architecture"),
    "COE" : ("College of Engineering", "engineering"),
    "CX" : ("Computational Mod, Sim, & Data", "computer"),
    "CSE" : ("Computational Science & Engineering", "computer"),
    "CS" : ("Computer Science", "computer"),
    "COOP" : ("Cooperative Work Assignment", "world"),
    "UCGA" : ("Cross Enrollment", "world"),
    "EAS" : ("Earth and Atmospheric Sciences", "science"),
    "ECON" : ("Economics", "econ"),
    "ECEP" : ("Electrical & Computer Engineering Professional", "engineering"),
    "ECE" : ("Electrical & Computer Engineering", "engineering"),
    "ENGL" : ("English", "language"),
    "FS" : ("Foreign Studies", "world"),
    "FREN" : ("French", "language"),
    "GT" : ("Georgia Tech", "gt"),
    "GTL" : ("Georgia Tech Lorraine", "world"),
    "GRMN" : ("German", "language"),
    "HS" : ("Health Systems", "science"),
    "HIST" : ("History", "world"),
    "HTS" : ("History of Technology & Society", "world"),
    "ISYE" : ("Industrial & Systems Engineering", "engineering"),
    "ID" : ("Industrial Design", "engineering"),
    "IPCO" : ("International Plan Co-op Abroad", "world"),
    "IPIN" : ("International Plan Intern Abroad", "world"),
    "IPFS" : ("International Plan-Exchange Program", "world"),
    "IPSA" : ("International Plan-Study Abroad", "world"),
    "INTA" : ("International Affairs", "world"),
    "IL" : ("International Logistics", "world"),
    "INTN" : ("Internship", "world"),
    "IMBA" : ("International Executive MBA", "world"),
    "JAPN" : ("Japanese", "language"),
    "KOR" : ("Korean", "language"),
    "LS" : ("Learning Support", "humanities"),
    "LING" : ("Linguistics", "language"),
    "LMC" : ("Literature", "language"),
    "MGT" : ("Management", "world"),
    "MOT" : ("Management of Technology", "world"),
    "MSE" : ("Materials Science & Engineering", "engineering"),
    "MATH" : ("Mathematics", "math"),
    "ME" : ("Mechanical Engineering", "engineering"),
    "MP" : ("Medical Physics", "science"),
    "MSL" : ("Military Science & Leadership", "humanities"),
    "MUSI" : ("Music", "music"),
    "NS" : ("Naval Science", "science"),
    "NRE" : ("Nuclear & Radiological Engineering", "science"),
    "PERS" : ("Persian", "language"),
    "PHIL" : ("Philosophy", "humanities"),
    "PHYS" : ("Physics", "science"),
    "POL" : ("Political Science", "humanities"),
    "PTFE" : ("Polymer, Textile and Fiber Engineering", "engineering"),
    "DOPP" : ("Professional Practice", "world"),
    "PSYC" : ("Psychology", "humanities"),
    "PUBP" : ("Public Policy", "humanities"),
    "PUBJ" : ("Public Policy/Joint GSU PhD", "humanities"),
    "RUSS" : ("Russian", "language"),
    "SOC" : ("Sociology", "humanities"),
    "SPAN" : ("Spanish", "language"),
]