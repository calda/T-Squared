//
//  Assignment.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 9/12/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation
import Kanna


class Assignment {
    
    enum CompletionStatus {
        case NotSubmitted, Completed, Returned
        
        static func fromString(string: String) -> CompletionStatus {
            if string.isEmpty || string.isWhitespace() { return .NotSubmitted }
            else if string.containsString("Returned") { return .Returned }
            else if string.containsString("Not") { return .NotSubmitted }
            else { return .Completed }
        }
        
    }
    
    let name: String
    let link: String
    let rawDueDateString: String
    let dueDate: NSDate?
    let status: CompletionStatus
    let owningClass: Class
    
    var message: String?
    var attachments: [Attachment]?
    var submissions: [Attachment]?
    var usesInlineText = false
    var feedback: String?
    var grade: String?
    
    init(name: String, link: String, dueDate: String, status: CompletionStatus, inClass owningClass: Class) {
        self.owningClass = owningClass
        self.name = name
        self.link = link
        self.rawDueDateString = dueDate
        self.status = status
        self.dueDate = dueDate.dateWithTSquareFormat()
    }
    
    func loadMessage(attempt attempt: Int = 0) {
        message = nil
        attachments = nil
        submissions = nil
        feedback = nil
        
        if let page = HttpClient.contentsOfPage(self.link) {
            
            //load returned grade
            if let dataTable = page.at_css(".itemSummary") {
                for row in dataTable.css("tr") {
                    if let rowName = row.css("th").first?.text where rowName.containsString("Grade") {
                        
                        if var rawGradeText = row.css("td").first?.text?.cleansed() {
                            
                            //add extra space that got stripped out since it was actually just a bunch of \t
                            if rawGradeText.containsString("(max") {
                                rawGradeText = rawGradeText.stringByReplacingOccurrencesOfString("(max", withString: " (max")
                            }
                            
                            //ignore "ungraded"
                            if !rawGradeText.containsString("Ungrades") {
                                self.grade = rawGradeText
                            }
                        }
                    }
                }
            }
            
            //load instructor message
            
            if !page.toHTML!.containsString("<div class=\"textPanel\">") {
                if attempt > 10 {
                    self.message = "Could not load message for assignment."
                }
                self.loadMessage(attempt: attempt + 1)
            }
            else {
                
                //load attachments if present
                //split into submissions and attachments
                let html = page.toHTML!
                let splits: [String]
                
                if html.containsString("<h5>Submitted Attachments</h5>") {
                    splits = page.toHTML!.componentsSeparatedByString("<h5>Submitted Attachments</h5>")
                }
                else if html.containsString("id=\"addSubmissionForm\"") {
                    splits = page.toHTML!.componentsSeparatedByString("id=\"addSubmissionForm\"")
                }
                else if html.containsString("Original submission text") {
                    splits = page.toHTML!.componentsSeparatedByString("Original submission text")
                }
                else if html.containsString("instructor\'s comments") {
                    splits = page.toHTML!.componentsSeparatedByString("instructor\'s comments")
                }
                else {
                    splits = [page.toHTML!]
                }
                
                let attachmentsPage = HTML(html: splits[0], encoding: NSUTF8StringEncoding)!
                let submissionsPage: HTMLDocument? = splits.count != 1 ? HTML(html: splits[1], encoding: NSUTF8StringEncoding)! : nil
                
                //load main message
                var message: String = ""
                
                for divTag in attachmentsPage.css("div") {
                    if divTag["class"] != "textPanel" { continue }
                    var text = divTag.textWithLineBreaks
                    if text.hasPrefix(" Assignment Instructions") {
                        text = (text as NSString).substringFromIndex(24)
                    }
                    message += text
                }
                
                message = message.withNoTrailingWhitespace()
                message = (message as NSString).stringByReplacingOccurrencesOfString("<o:p>", withString: "")
                message = (message as NSString).stringByReplacingOccurrencesOfString("</o:p>", withString: "")
                self.message = message
                
                //load attachments
                for link in attachmentsPage.css("a, link") {
                    let linkURL = link["href"] ?? ""
                    if linkURL.containsString("/attachment/") {
                        let attachment = Attachment(link: linkURL, fileName: link.text?.cleansed() ?? "Attached file")
                        if self.attachments == nil { self.attachments = [] }
                        self.attachments!.append(attachment)
                    }
                }
                
                //load submissions
                if let submissionsPage = submissionsPage {
                    
                    //load submission attachments
                    for link in submissionsPage.css("a, link") {
                        let linkURL = link["href"] ?? ""
                        if linkURL.containsString("/attachment/") {
                            let attachment = Attachment(link: linkURL, fileName: link.text?.cleansed() ?? "Attached file")
                            if self.submissions == nil { self.submissions = [] }
                            self.submissions!.append(attachment)
                        }
                    }
                    
                    var submittedString: String?
                    
                    //load submitted text
                    if html.containsString("Original submission text") {
                        for div in submissionsPage.css("div") {
                            if div["class"] != "textPanel" { continue }
                            submittedString = div.toHTML!
                            var trimmedText = submittedString?.stringByReplacingOccurrencesOfString("<div class=\"textPanel\">", withString: "")
                            trimmedText = trimmedText?.stringByReplacingOccurrencesOfString("</div>", withString: "")
                            
                            var title = "Submitted Text"
                            let links = linksInText(trimmedText!)
                            if links.count == 1 && trimmedText!.cleansed() == links[0].text {
                                title = websiteForLink(links[0].text)
                            }
                            
                            let submittedText = Attachment(fileName: title, rawText: trimmedText!)
                            if self.submissions == nil { self.submissions = [] }
                            self.submissions!.append(submittedText)
                            self.usesInlineText = true
                            break
                        }
                    }
                    
                    //load submission comments
                    var feedback: String = ""
                    
                    for divTag in submissionsPage.css("div") {
                        if divTag["class"] != "textPanel" { continue }
                        if divTag.toHTML! == (submittedString ?? "") { continue }
                        feedback += divTag.textWithLineBreaks
                    }
                    
                    if feedback != "" {
                        self.feedback = feedback.withNoTrailingWhitespace()
                    }
                    
                }
                
            }
        }
    }
    
}
