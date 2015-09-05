//
//  Resource.swift
//  T-Square
//
//  Created by Cal on 9/4/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation

class Resource {
    
    let name: String
    let link: String
    let isFolder: Bool
    var resourcesInFolder: [Resource]? = nil
    
    init(name: String, link: String) {
        self.name = name
        self.link = link
        self.isFolder = link.containsString("/portal/pda") || link == "#"
    }
    
}