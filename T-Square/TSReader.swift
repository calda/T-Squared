//
//  TSReader.swift
//  T-Square
//
//  Created by Cal on 8/27/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation

class TSReader {
    
    static func authenticatedReader(user user: String, password: String, completion: (TSReader?) -> ()) {
        HttpClient.authenticateWithUsername(user, password: password, completion: { success in
            completion(success ? TSReader() : nil)
        })
    }
    
    func getClasses() -> [String] {
        let document = HttpClient.contentsOfPage("https://t-square.gatech.edu/portal")
        print(document)
        return []
    }
    
}