//
//  MkdownChunk.swift
//  Notenik
//
//  Created by Herb Bowie on 3/3/20.
//  Copyright © 2020 Herb Bowie (https://powersurgepub.com)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

/// One chunk of characters from one Markdown line. 
class MkdownChunk {
    var text = ""
    var type: MkdownChunkType = .plaintext
    var lineType: MkdownLineType = .ordinaryText
    var startsWithSpace = false
    var endsWithSpace = false
    
    var textCount = 0
    var wordCount = 0
    
    var columnsToSpan = 1
    
    var spaceBefore = true
    var _spaceAfter = true
    var spaceAfter: Bool {
        get {
            return _spaceAfter
        }
        set {
            _spaceAfter = newValue
            if spaceBefore && _spaceAfter {
                if emphasisChar {
                    type = .literal
                }
            }
        }
    }
    
    init() {
        
    }
    
    init(line: MkdownLine) {
        lineType = line.type
    }
    
    var emphasisChar: Bool {
        return type == .asterisk || type == .underline
    }
    
    var tablePipe: Bool {
        return type == .tableHeaderPipe || type == .tableDataPipe
    }
    
    func setTextFrom(char: Character) {
        text = String(char)
    }
    
    func display(title: String = "", indenting: Int = 0) {
        let indent = String(repeating: " ", count: indenting)
        if title.count > 0 {
            print(" ")
            print("\(indent)\(title)")
        }
        var line = indent
        line.append("Chunk type: \(type), ")
        line.append("words: \(wordCount), ")
        line.append("letters: \(textCount), ")
        if startsWithSpace {
            line.append("starts with space, ")
        }
        if endsWithSpace {
            line.append("ends with space, ")
        }
        line.append("text: '\(text)'")
        print(line)
    }
}
