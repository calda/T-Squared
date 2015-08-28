//
//  Announcement.swift
//  T-Square
//
//  Created by Cal on 8/28/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import Kanna

class Announcement : CustomStringConvertible {
    
    let owningClass: Class
    let name: String
    var message: String?
    var author: String
    var date: String
    let link: String
    
    var description: String {
        return name
    }
    
    init(inClass: Class, name: String, author: String, date: String, link: String) {
        self.owningClass = inClass
        self.name = name
        self.author = author
        self.date = date
        self.link = link
    }
    
    func loadMessage(completion: (String) -> ()) {
        //only load if necessary
        if let message = self.message {
            completion(message)
            return
        }
        
        //load message
        dispatch_async(TSNetworkQueue, {
            if let page = HttpClient.contentsOfPage(self.link) {
                //sift through the table
                var author: String = ""
                var date: String = ""
                
                let table = page.css("table")[0]
                for row in table.css("tr") {
                    let rowName = row.css("th")[0].text!
                    let rowData = row.css("td")[0].text!.cleansed()
                    
                    //save data from row is it's important
                    switch(rowName) {
                    case "Saved By": author = rowData; break;
                    case "Modified Date": date = rowData; break;
                    default: break;
                    }
                }
                
                self.author = author
                self.date = date
                
                let messageTag = page.css("p")[0]
                self.message = messageTag.text!.cleansed().cleansed()
                sync() { completion(self.message!) }
            }
            else {
                sync() { completion("Couldn't load message.") }
            }
        })
    }
    
}