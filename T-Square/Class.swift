//
//  Class.swift
//  T-Square
//
//  Created by Cal on 8/27/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import Kanna

class Class : CustomStringConvertible {
    
    let ID: String
    let subjectName: String?
    var name: String
    let link: String
    var classPage: HTMLDocument?
    
    var description: String {
        return name
    }
    
    init(fromElement element: XMLElement) {
        ID = element.text!.cleansed()
        link = element["href"]!.stringByReplacingOccurrencesOfString("site", withString: "pda")
        
        //create user-facing name
        let nameParts = ID.componentsSeparatedByString("-")
        self.name = nameParts[0] + " " + nameParts[1]
        self.subjectName = GTSubjects[nameParts[0]]
    }
    
    func useSectionName() {
        self.name = (ID as NSString).stringByReplacingOccurrencesOfString("-", withString: " ")
    }
    
    func getClassPage() ->  HTMLDocument? {
        if let classPage = self.classPage { return classPage }
        return HttpClient.contentsOfPage(self.link)
    }
    
}

let GTSubjects: [String : String] = [
    "ACCT" : "Accounting",
    "AE" : "Aerospace Engineering",
    "AS" : "Air Force Aerospace Studies",
    "APPH" : "Applied Physiology",
    "ASE" : "Applied Systems Engineering",
    "ARBC" : "Arabic",
    "ARCH" : "Architecture",
    "BIOL" : "Biology",
    "BMEJ" : "Biomed Engineering/Joint Emory PKU",
    "BMED" : "Biomedical Engineering",
    "BMEM" : "Biomedical Engineering/Joint Emory",
    "BC" : "Building Construction",
    "CETL" : "Center Enhancement Teach/Learn",
    "CHBE" : "Chemical & Biomolecular Engr",
    "CHEM" : "Chemistry",
    "CHIN" : "Chinese",
    "CP" : "City Planning",
    "CEE" : "Civil and Environmental Engineering",
    "COA" : "College of Architecture",
    "COE" : "College of Engineering",
    "CX" : "Computational Modeling : Simulation : & Data",
    "CSE" : "Computational Science & Engineering",
    "CS" : "Computer Science",
    "COOP" : "Cooperative Work Assignment",
    "UCGA" : "Cross Enrollment",
    "EAS" : "Earth and Atmospheric Sciences",
    "ECON" : "Economics",
    "ECEP" : "Electrical & Computer Engineering Professional",
    "ECE" : "Electrical & Computer Engineering",
    "ENGL" : "English",
    "FS" : "Foreign Studies",
    "FREN" : "French",
    "GT" : "Georgia Tech",
    "GTL" : "Georgia Tech Lorraine",
    "GRMN" : "German",
    "HS" : "Health Systems",
    "HIST" : "History",
    "HTS" : "History : Technology & Society",
    "ISYE" : "Industrial & Systems Engr",
    "ID" : "Industrial Design",
    "IPCO" : "International Plan Co-op Abroad",
    "IPIN" : "International Plan Intern Abroad",
    "IPFS" : "International Plan-Exchange Program",
    "IPSA" : "International Plan-Study Abroad",
    "INTA" : "International Affairs",
    "IL" : "International Logistics",
    "INTN" : "Internship",
    "IMBA" : "Intl Executive MBA",
    "JAPN" : "Japanese",
    "KOR" : "Korean",
    "LS" : "Learning Support",
    "LING" : "Linguistics",
    "LMC" : "Literature : Media & Communication",
    "MGT" : "Management",
    "MOT" : "Management of Technology",
    "MSE" : "Materials Science & Engineering",
    "MATH" : "Mathematics",
    "ME" : "Mechanical Engineering",
    "MP" : "Medical Physics",
    "MSL" : "Military Science & Leadership",
    "MUSI" : "Music",
    "NS" : "Naval Science",
    "NRE" : "Nuclear & Radiological Engineering",
    "PERS" : "Persian",
    "PHIL" : "Philosophy",
    "PHYS" : "Physics",
    "POL" : "Political Science",
    "PTFE" : "Polymer : Textile and Fiber Eng",
    "DOPP" : "Professional Practice",
    "PSYC" : "Psychology",
    "PUBP" : "Public Policy",
    "PUBJ" : "Public Policy/Joint GSU PhD",
    "RUSS" : "Russian",
    "SOC" : "Sociology",
    "SPAN" : "Spanish"
]