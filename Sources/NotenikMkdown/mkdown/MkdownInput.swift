//
//  MkdownInput.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 1/7/22.
//
//  Copyright © 2022 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

/// Return a string, one character at a time.
public class MkdownInput {
    
    var mkdown = ""
    
    var indices: [String.Index] = []
    var nextIndex: String.Index {
        get {
            if indices.count > 0 {
                return indices[0]
            } else {
                return mkdown.startIndex
            }
        }
        set {
            if indices.isEmpty {
                indices.append(newValue)
            } else {
                indices[0] = newValue
            }
        }
    }
    
    var lastIndex: String.Index {
        get {
            if indices.count > 1 {
                return indices[1]
            } else {
                return mkdown.startIndex
            }
        }
        set {
            if indices.isEmpty {
                indices.append(mkdown.startIndex)
            }
            if indices.count < 2 {
                indices.append(newValue)
            } else {
                indices[1] = newValue
            }
        }
    }
    
    var currChar:   Character = " "
    
    public var endOfChars = false
    var endOfCharsPending = false
    
    public var count: Int { return mkdown.count }
    
    /// Initialize with an empty string.
    public init() {
        indices = []
        for _ in MkdownInputPosition.allCases {
            let nextPosition = mkdown.startIndex
            indices.append(nextPosition)
        }
    }
    
    /// Initialize with a passed string.
    public init(_ mkdown: String) {
        self.mkdown = mkdown
        indices = []
        for _ in MkdownInputPosition.allCases {
            let nextPosition = mkdown.startIndex
            indices.append(nextPosition)
        }
    }
    
    /// Attempt to initialize directly from a file URL.
    public init?(fileURL: URL) {
        do {
            mkdown = try String(contentsOf: fileURL, encoding: .utf8)
            indices = []
            for _ in MkdownInputPosition.allCases {
                let nextPosition = mkdown.startIndex
                indices.append(nextPosition)
            }
        } catch {
            return nil
        }
    }
    
    /// Set a new value for the string to be read, and position ourselves at the
    /// beginning of the string.
    func set (_ mkdown: String) {
        self.mkdown = mkdown
        initVars()
    }
    
    public func reset() {
        initVars()
    }
    
    func initVars() {
        
        indices = []
        for _ in MkdownInputPosition.allCases {
            let nextPosition = mkdown.startIndex
            indices.append(nextPosition)
        }
        
        currChar = " "
        endOfChars = false
        endOfCharsPending = false
    }
    
    /// Read the next character, setting a flag at the end of the available text,
    /// and ensuring a newline before the end. 
    public func nextChar() -> Character? {
        if endOfChars {
            return nil
        } else if endOfCharsPending {
            endOfChars = true
            currChar = "\n"
        } else if nextIndex >= mkdown.endIndex {
            endOfChars = true
            return nil
        } else {
            currChar = mkdown[nextIndex]
            lastIndex = nextIndex
            nextIndex = mkdown.index(after: nextIndex)
            if nextIndex >= mkdown.endIndex {
                if currChar.isNewline {
                    endOfChars = true
                } else {
                    endOfCharsPending = true
                }
            }
        }
        return currChar
    }
    
    public func setIndex(_ target: MkdownInputPosition, to: MkdownInputPosition) {
        indices[target.rawValue] = indices[to.rawValue]
    }
    
    public func indexAfter(_ target: MkdownInputPosition) {
        indices[target.rawValue] = mkdown.index(after: indices[target.rawValue])
    }
    
    public func indexBefore(_ target: MkdownInputPosition) {
        indices[target.rawValue] = mkdown.index(before: indices[target.rawValue])
    }
    
    public func getLine() -> String {
        return getString(from: .startLine, to: .endLine)
    }
    
    public func getText() -> String {
        return getString(from: .startText, to: .endText)
    }
    
    public func getString(from: MkdownInputPosition, to: MkdownInputPosition) -> String {
        let fromIndex = indices[from.rawValue]
        let toIndex   = indices[to.rawValue]
        if toIndex > fromIndex {
            return String(mkdown[fromIndex..<toIndex])
        } else {
            return ""
        }
    }
    
    public enum MkdownInputPosition: Int, CaseIterable {
        case next = 0
        case last = 1
        case startText = 2
        case startLine = 3
        case endLine = 4
        case endText = 5
        case startNumber = 6
        case startBullet = 7
        case startColon = 8
        case startHash = 9
        case startMathDelims = 10
        case startMath = 11
        case endMath = 12
    }
}
