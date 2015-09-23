//
//  Grade.swift
//  T-Square
//
//  Created by Cal on 9/22/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation

protocol Scored {
    
    var score: Double? { get }
    var weight: Double? { get }
    
}

class Grade : Scored, CustomStringConvertible {
    
    let name: String
    let score: Double?
    let weight: Double?
    let comment: String?
    
    init(name: String, score: String?, weight: String?, comment: String?) {
        self.name = name
        self.score = nil
        self.weight = nil
        self.comment = comment
    }
    
    var description: String {
        return "\(name)(score=\(score))"
    }
    
}

class GradeGroup : Scored, CustomStringConvertible {
    
    let name: String
    let weight: Double?
    var scores: [Scored] = []
    
    init(name: String, weight: String?) {
        self.name = name
        self.weight = nil
    }
    
    init(name: String, weight: Double?) {
        self.name = name
        self.weight = weight
    }
    
    var score: Double? {
        if scores.count == 0 { return nil }
        
        //unweighted calculation
        if scores[0].weight == nil {
            var sumScore = 0.0
            for score in scores {
                sumScore += score.score ?? 0.0
            }
            return sumScore / Double(scores.count)
        }
        
        //weighted calculation
        else {
            var finalScore = 0.0
            for score in scores {
                if let numScore = score.score, let weight = score.weight {
                    finalScore += (numScore * weight)
                }
            }
            return finalScore
        }
    }
    
    var description: String {
        return "\(name)\(scores)"
    }
    
}