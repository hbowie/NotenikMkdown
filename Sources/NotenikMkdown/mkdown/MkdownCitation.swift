//
//  MkdownCitation.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 11/4/20.
//  Copyright © 2020 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

class MkdownCitation: Comparable, Equatable {
    var label = ""
    var number = 0
    var text  = ""
    var inputLine = ""
    var cited = true
    var lines: [MkdownLine] = []
    
    var hasLabel: Bool {
        return label.count > 0
    }
    
    var isValid: Bool {
        return label.count > 0 && text.count > 0
    }
    
    func pruneTrailingBlankLines() {
        var i = lines.count - 1
        var moreBlanks = true
        while i >= 0 && moreBlanks {
            let line = lines[i]
            if line.type == .blank {
                lines.remove(at: i)
                i -= 1
            } else {
                moreBlanks = false
            }
        }
    }
    
    func display() {
        print("citation # \(number) \(label): \(text)")
        var lineIndex = 0
        while lineIndex < lines.count {
            print("  additional line: \(lines[lineIndex].text)")
            lineIndex += 1
        }
    }
    
    static func < (lhs: MkdownCitation, rhs: MkdownCitation) -> Bool {
        return lhs.number < rhs.number
    }
    
    static func == (lhs: MkdownCitation, rhs: MkdownCitation) -> Bool {
        return lhs.number == rhs.number
    }
}
