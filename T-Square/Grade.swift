//
//  Grade.swift
//  T-Square
//
//  Created by Cal on 9/22/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation

protocol Scored {
    
    var name: String { get }
    var score: Double? { get }
    var scoreString: String { get }
    var weight: Double? { get }
    
}

class Grade : Scored, CustomStringConvertible {
    
    let name: String
    let score: Double?
    let scoreString: String
    let weight: Double?
    let comment: String?
    
    init(name: String, score: String?, weight: String?, comment: String?) {
        self.name = name
        self.comment = comment
        self.scoreString = score?.cleansed() ?? "-"
        
        //parse score
        if scoreString.hasSuffix("%") {
            if let percentScore = scoreString.percentStringAsDouble() {
                self.score = percentScore
                self.weight = 100.0
                return
            }
        }
        else if scoreString.containsString("/") {
            let splits = scoreString.componentsSeparatedByString("/")
            if splits.count >= 2 {
                if let points = splits[0].asDouble(), let total = splits[1].asDouble() {
                    self.score = points / total
                    self.weight = total
                    return
                }
            }
        }
        
        self.score = nil
        self.weight = nil
    }
    
    var description: String {
        return "\(name)(score=\(scoreString))"
    }
    
}

class GradeGroup : Scored, CustomStringConvertible {
    
    let name: String
    let weight: Double?
    var scores: [Scored] = []
    
    init(name: String, weight: String?) {
        self.name = name
        print(weight)
        if let weightString = weight?.cleansed() where weightString.hasSuffix("%") {
            if let percent = weightString.percentStringAsDouble() {
                self.weight = percent * 100.0
                print(self.weight)
                return
            }
        }
        self.weight = nil
    }
    
    init(name: String, weight: Double?) {
        self.name = name
        self.weight = weight
    }
    
    var score: Double? {
        if scores.count == 0 { return nil }
        var totalPoints = 0.0
        var totalWeight = 0.0
        
        for score in scores {
            if let points = score.score, let weight = score.weight {
                totalPoints += (points * weight)
                totalWeight += weight
            }
        }
        
        if totalWeight == 0.0 { return nil }
        return totalPoints / totalWeight
    }
    
    var scoreString: String {
        if let score = score {
            let rounded = Double(Int(score * 10000) / 100)
            return "\(rounded)%"
        }
        return "-"
    }
    
    var description: String {
        return "\(name) [total score = \(self.scoreString)]\(scores)"
    }
    
    var flattened: [Scored] {
        var flattenedArray: [Scored] = []
        for score in scores {
            if let group = score as? GradeGroup {
                flattenedArray.append(group)
                if group.scores.count == 0 {
                    flattenedArray.append(Grade(name: "Nothing here yet.", score: "", weight: nil, comment: nil))
                }
                else {
                    flattenedArray.appendContentsOf(group.flattened)
                }
            }
            else {
                flattenedArray.append(score)
            }
        }
        return flattenedArray
    }
    
}