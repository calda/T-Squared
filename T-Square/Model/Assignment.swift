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
        case notSubmitted, completed, returned
        
        static func fromString(_ string: String) -> CompletionStatus {
            if string.isEmpty || string.isWhitespace() { return .notSubmitted }
            else if string.contains("Returned") { return .returned }
            else if string.contains("Not") { return .notSubmitted }
            else { return .completed }
        }
        
    }
    
    let name: String
    let link: String
    let rawDueDateString: String
    let dueDate: Date?
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
        self.dueDate = dueDate.dateWithTSquareFormat() as Date?
    }
    
    func loadMessage(attempt: Int = 0) {
        message = nil
        attachments = nil
        submissions = nil
        feedback = nil
        
        if let page = HttpClient.contentsOfPage(self.link) {
            
            //load returned grade
            if let dataTable = page.at_css(".itemSummary") {
                for row in dataTable.css("tr") {
                    if let rowName = row.css("th").first?.text, rowName.contains("Grade") {
                        
                        if var rawGradeText = row.css("td").first?.text?.cleansed() {
                            
                            //add extra space that got stripped out since it was actually just a bunch of \t
                            if rawGradeText.contains("(max") {
                                rawGradeText = rawGradeText.replacingOccurrences(of: "(max", with: " (max")
                            }
                            
                            //ignore "ungraded"
                            if !rawGradeText.contains("Ungrades") {
                                self.grade = rawGradeText
                            }
                        }
                    }
                }
            }
            
            //load instructor message
            
            if !page.toHTML!.contains("<div class=\"textPanel\">") {
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
                
                if html.contains("<h5>Submitted Attachments</h5>") {
                    splits = page.toHTML!.components(separatedBy: "<h5>Submitted Attachments</h5>")
                }
                else if html.contains("id=\"addSubmissionForm\"") {
                    splits = page.toHTML!.components(separatedBy: "id=\"addSubmissionForm\"")
                }
                else if html.contains("Original submission text") {
                    splits = page.toHTML!.components(separatedBy: "Original submission text")
                }
                else if html.contains("instructor\'s comments") {
                    splits = page.toHTML!.components(separatedBy: "instructor\'s comments")
                }
                else {
                    splits = [page.toHTML!]
                }
                
                do {
                    let attachmentsPage = try HTML(html: splits[0], encoding: String.Encoding.utf8)
                    let submissionsPage: HTMLDocument? = try splits.count != 1 ? HTML(html: splits[1], encoding: String.Encoding.utf8) : nil
                    
                    //load main message
                    var message: String = ""
                    
                    for divTag in attachmentsPage.css("div") {
                        if divTag["class"] != "textPanel" { continue }
                        var text = divTag.textWithLineBreaks
                        if text.hasPrefix(" Assignment Instructions") {
                            text = (text as NSString).substring(from: 24)
                        }
                        message += text
                    }
                    
                    message = message.withNoTrailingWhitespace()
                    message = (message as NSString).replacingOccurrences(of: "<o:p>", with: "")
                    message = (message as NSString).replacingOccurrences(of: "</o:p>", with: "")
                    self.message = message
                    
                    //load attachments
                    for link in attachmentsPage.css("a, link") {
                        let linkURL = link["href"] ?? ""
                        if linkURL.contains("/attachment/") {
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
                            if linkURL.contains("/attachment/") {
                                let attachment = Attachment(link: linkURL, fileName: link.text?.cleansed() ?? "Attached file")
                                if self.submissions == nil { self.submissions = [] }
                                self.submissions!.append(attachment)
                            }
                        }
                        
                        var submittedString: String?
                        
                        //load submitted text
                        if html.contains("Original submission text") {
                            for div in submissionsPage.css("div") {
                                if div["class"] != "textPanel" { continue }
                                submittedString = div.toHTML!
                                var trimmedText = submittedString?.replacingOccurrences(of: "<div class=\"textPanel\">", with: "")
                                trimmedText = trimmedText?.replacingOccurrences(of: "</div>", with: "")
                                
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
                } catch  {
                    print("fatal error in Assignment.swift")
                }
                
                
            }
        }
    }
    
}
