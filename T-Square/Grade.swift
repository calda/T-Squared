//
//  Grade.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 9/22/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation

protocol Scored {
    
    var name: String { get }
    var score: Double? { get }
    var scoreString: String { get }
    var weight: Double? { get }
    var isArtificial: Bool { get }
    
    func representAsString() -> String
    
    var owningGroup: GradeGroup? { get set }
    var owningGroupName: String? { get set }
    
}

func scorefromString(string: String, isArtificial: Bool) -> Scored? {
    
    if string.hasPrefix("GRADE") {
        let splits = string.componentsSeparatedByString("~")
        if splits.count != 4 && splits.count != 5 { return nil }
        
        //comment (index 4) may or may not exist
        let comment: String? = splits.count >= 5 ? splits[4] : nil
        
        let grade = Grade(name: splits[2], score: splits[3], weight: nil, comment: comment, isArtificial: isArtificial)
        grade.owningGroupName = splits[1]
        return grade
    }
    
    if string.hasPrefix("GROUP") {
        let splits = string.componentsSeparatedByString("~")
        if splits.count != 3 && splits.count != 4 { return nil }
        
        let group = GradeGroup(name: splits[1], weight: "\(splits[2])%", isArtificial: isArtificial)
        
        //intrinsic grade (index 4) may or may not exist
        let intrinsicGradeString: String? = splits.count >= 4 ? splits[3] : nil
        //use Grade to parse
        let parser = Grade(name: "parse", score: intrinsicGradeString, weight: nil, comment: nil)
        if let intrinsicGrade = parser.score {
            group.intrinsicScore = intrinsicGrade
        }
        
        return group
    }
    
    return nil
}

func equalityFunctionForScore(score: Scored) -> (Scored) -> Bool {
    return { other in
        if let grade = score as? Grade, let other = other as? Grade {
            return grade.name == other.name && grade.score == other.score && grade.isArtificial == other.isArtificial
        }
        if let group = score as? GradeGroup, let other = other as? GradeGroup {
            return group.name == other.name && group.score == other.score && group.scores.count == other.scores.count && group.isArtificial == other.isArtificial
        }
        return false
    }
}

class Grade : Scored, CustomStringConvertible {
    
    let name: String
    let score: Double?
    let scoreString: String
    let weight: Double?
    let comment: String?
    
    var isArtificial: Bool = false
    var owningGroup: GradeGroup?
    var owningGroupName: String?
    
    var contributesToAverage: Bool = true
    
    init(name: String, score: String?, weight: String?, comment: String?, isArtificial: Bool = false) {
        self.name = name
        self.comment = comment
        self.scoreString = score?.cleansed() ?? "—"
        self.isArtificial = isArtificial
        
        if scoreString.hasPrefix("(") { contributesToAverage = false }
        let scoreToParse = scoreString.stringByReplacingOccurrencesOfString("(", withString: "").stringByReplacingOccurrencesOfString(")", withString: "")
        
        //parse score
        if scoreToParse.hasSuffix("%") {
            if let percentScore = scoreToParse.percentStringAsDouble() {
                self.score = percentScore
                self.weight = 100.0
                return
            }
        }
        else if scoreToParse.containsString("/") {
            let splits = scoreToParse.componentsSeparatedByString("/")
            if splits.count >= 2 {
                if let points = splits[0].asDouble(), let total = splits[1].asDouble() {
                    
                    if total == 0 { //prevent divide by zero
                        self.score = nil
                        self.weight = nil
                        return
                    }
                    
                    self.score = points / total
                    self.weight = total
                    return
                }
            }
        }
        
        self.score = nil
        self.contributesToAverage = false
        self.weight = nil
    }
    
    var description: String {
        return "\(name)(score=\(scoreString))"
    }
    
    func representAsString() -> String {
        var string = "GRADE~\(owningGroup?.name ?? "")~\(name)~\(scoreString)"
        if let comment = comment {
            let strippedComment = comment.stringByReplacingOccurrencesOfString("~", withString: "-")
            string.appendContentsOf("~\(strippedComment)")
        }
        return string
    }
    
    func performDropCheckWithClass(owningClass: Class) {
        //check if this grade has been artificially dropped by the user
        let data = NSUserDefaults.standardUserDefaults()
        var dict = data.dictionaryForKey(TSDroppedGradesKey) as? [String : [String]] ?? [:]
        let classKey = TSAuthenticatedReader.username + "~" + owningClass.permanentID
        let droppedClasses = dict[classKey] ?? []
        
        if droppedClasses.contains(self.representAsString()) {
            self.contributesToAverage = false
        }
    }
    
}

class GradeGroup : Scored, CustomStringConvertible {
    
    let name: String
    let weight: Double?
    var scores: [Scored] = []
    var intrinsicScore: Double?
    let isArtificial: Bool
    var owningGroup: GradeGroup?
    var owningGroupName: String?
    
    ///for N scores, should appear as "Edited" if count of artificial grades is between (0, N)
    var shouldAppearAsEdited: Bool {
        var artificialCount = 0
        var totalCount = 0
        for score in scores {
            
            //a grade counts as edited if it is
            // (1) created artificially
            // (2) dropped by the user, meaning !isArtificial and !contributesToAverage
            func countsAsEdit(scored: Scored) -> Bool {
                var isEdit = scored.isArtificial
                if let grade = scored as? Grade {
                    isEdit = isEdit || (!grade.contributesToAverage && grade.score != nil)
                }
                return isEdit
            }
            
            if countsAsEdit(score) { artificialCount++ }
            totalCount++
            
            if let group = score as? GradeGroup {
                for score in group.scores {
                    if countsAsEdit(score) { artificialCount++ }
                    totalCount++
                }
            }
            
        }
    
        return artificialCount > 0 && artificialCount != totalCount
    }
    
    init(name: String, weight: String?, isArtificial: Bool = false) {
        self.name = name
        self.isArtificial = isArtificial
        if let weightString = weight?.cleansed() where weightString.hasSuffix("%") {
            if let percent = weightString.percentStringAsDouble() {
                self.weight = percent * 100.0
                return
            }
        }
        self.weight = nil
    }
    
    init(name: String, weight: Double?, isArtificial: Bool = false) {
        self.name = name
        self.weight = weight
        self.isArtificial = isArtificial
    }
    
    func asRootGroupForClass(currentClass: Class) -> GradeGroup {
        let data = NSUserDefaults.standardUserDefaults()
        let dict: [String : Bool] = data.dictionaryForKey(TSGradebookCalculationSettingKey) as? [String : Bool] ?? [:]
        useAllSubscores = dict[currentClass.permanentID] ?? false
        return self
    }
    
    var useAllSubscores = false {
        didSet {
            for score in scores {
                if let group = score as? GradeGroup {
                    group.useAllSubscores = self.useAllSubscores
                }
            }
        }
    }
    
    var ignoreSubgroupScores = false
    
    var scoreFraction: (totalPoints: Double, totalWeight: Double) {
        var totalPoints = 0.0
        var totalWeight = 0.0
        
        for score in scores {
            if (score as? Grade)?.contributesToAverage == false && self.useAllSubscores == false { continue }
            if let points = score.score, let weight = score.weight {
                totalPoints += (points * weight)
                totalWeight += weight
            }
        }
        
        if totalPoints == 0.0 && totalWeight == 0.0 {
            //no points/weight
            //this might be an instance where the grade groups don't have weights
            var groupCount = 0
            for score in scores {
                if score is GradeGroup { groupCount += 1 }
            }
            
            if groupCount == scores.count {
                ignoreSubgroupScores = true
                //add up all of the points and weights from the sub-grades
                for unwrappedGroup in scores where unwrappedGroup is GradeGroup {
                    let group = unwrappedGroup as! GradeGroup
                    let (points, weight) = group.scoreFraction
                    totalPoints += points
                    totalWeight += weight
                }
            }
        } else {
            ignoreSubgroupScores = false
        }
        
        return (totalPoints, totalWeight)
    }
    
    var score: Double? {
        if scores.count == 0 { return intrinsicScore }
        
        let (totalPoints, totalWeight) = scoreFraction
        if totalWeight == 0.0 { return nil }
        return totalPoints / totalWeight
    }
    
    var scoreString: String {
        if let score = score {
            let rounded = Double(Int(score * 1000)) / 10.0
            var roundedString = "\(rounded)"
            if roundedString.hasSuffix(".0") {
                roundedString = (roundedString as NSString).substringToIndex(roundedString.length - 2)
            }
            return "\(roundedString)%"
        }
        return "-"
    }
    
    var fractionString: String? {
        //decide if the fractionString should ber used
        var subcountWithFraction = 0
        
        for score in scores {
            
            if let group = score as? GradeGroup {
                
                //there is a certain set of requirements that must be met for a Grade Group to be considered a fraction
                // 1) all of it's subscores must be fractions, meaning group.fractionString is not nil
                // 2) the group has no weight (a weight would change the reported fractions)
                if group.fractionString != nil && (group.weight == nil || group.weight == 0.0) {
                    subcountWithFraction += 1
                }
                
            } else {
                if score.scoreString.containsString("/") || score.score == nil {
                    subcountWithFraction += 1
                }
            }
        }
        
        if subcountWithFraction == scores.count && scores.count > 0 {
            let (totalPoints, totalWeight) = scoreFraction
            let fractionString = "\(totalPoints) / \(totalWeight)".stringByReplacingOccurrencesOfString(".0", withString: "")
            return fractionString
        }
        return nil
    }
    
    var description: String {
        return "\(name) [total score = \(self.scoreString)]\(scores)"
    }
    
    var flattened: [Scored] {
        var flattenedArray: [Scored] = []
        
        if self.name == "ROOT" && (scores.count > 0 && scores[0] is Grade) {
            flattenedArray.append(Grade(name: "", score: "", weight: nil, comment: nil))
        }
        
        for score in scores {
            if let group = score as? GradeGroup {
                flattenedArray.append(group)
                if group.scores.count == 0 && group.intrinsicScore == nil {
                    flattenedArray.append(Grade(name: "Nothing here yet.", score: "", weight: nil, comment: nil))
                }
                else {
                    flattenedArray.appendContentsOf(group.flattened)
                }
                
                flattenedArray.append(Grade(name: "", score: "", weight: nil, comment: nil))
            }
            else {
                flattenedArray.append(score)
                if let grade = score as? Grade, let comment = grade.comment?.cleansed() where comment != "" && comment != "from Assignments" && comment != "from Tests & Quizzes" {
                    flattenedArray.append(Grade(name: comment, score: "COMMENT_PLACEHOLDER", weight: nil, comment: nil))
                }
            }
        }
        
        if flattenedArray.last?.name == "" {
            flattenedArray.removeLast() //remove the trailing placeholder if it's empty
        }
        
        return flattenedArray
    }
    
    func representAsString() -> String {
        var string = "GROUP~\(name)~\(weight ?? 0)"
        if self.scores.count == 0 && self.score != nil { //has an intrinsic grade
            string += "~\(self.scoreString)"
        }
        return string
    }
    
}