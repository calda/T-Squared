//
//  Assignment.swift
//  T-Square
//
//  Created by Cal on 9/12/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation

class Assignment {
    
    let name: String
    let link: String
    let rawDueDateString: String
    let dueDate: NSDate?
    let completed: Bool
    
    init(name: String, link: String, dueDate: String, completed: Bool) {
        self.name = name
        self.link = link
        self.rawDueDateString = dueDate
        self.completed = completed
        self.dueDate = dueDate.dateWithTSquareFormat()
    }
    
}