//
//  ClassesView.swift
//  T-Square
//
//  Created by Cal on 8/27/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import UIKit

class ClassesViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {

    var classes: [Class]?
    @IBOutlet weak var tableView: UITableView!
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return classes?.count ?? 0
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 70.0
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let index = indexPath.item
        if let classes = classes {
            let displayClass = classes[index]
            let cell = tableView.dequeueReusableCellWithIdentifier("class") as! ClassNameCell
            cell.decorate(displayClass)
            return cell
        }
        
        return tableView.dequeueReusableCellWithIdentifier("class")!
    }
    
}

class ClassNameCell : UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var subjectLabel: UILabel!
    
    func decorate(displayClass: Class) {
        nameLabel.text = displayClass.name
        subjectLabel.text = displayClass.subjectName ?? ""
    }
    
}