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
        
        let doc = HttpClient.contentsOfPage("https://t-square.gatech.edu/portal")
        
        var classes: [Class] = []
        var saveLinksAsClasses: Bool = false
        
        for link in doc.css("a, link") {
            if let text = link.text {
                
                //class links start after My Workspace tab
                if !saveLinksAsClasses && text == "My Workspace" {
                    saveLinksAsClasses = true
                }
                
                else if saveLinksAsClasses {
                    //find the end of the class links
                    if text == "" || text.hasPrefix("\n") {
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
    
}