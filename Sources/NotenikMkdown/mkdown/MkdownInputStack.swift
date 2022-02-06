//
//  MkdownInputStack.swift
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

/// Return one character at a time from a dynamic nested series of strings.
public class MkdownInputStack {
    
    var stack: [MkdownInput] = []
    
    var currChar: Character = " "
    
    /// Indicates end of all files.
    public var endOfChars = false
    public var moreChars: Bool { return !endOfChars }
    
    public init() {
        
    }
    
    public convenience init(_ str: String) {
        self.init()
        push(str)
    }
    
    public convenience init(_ reader: MkdownInput) {
        self.init()
        push(reader)
    }
    
    public func reset() {
        while stack.count > 1 {
            stack.removeLast()
        }
        if !stack.isEmpty {
            mkdownInput.reset()
        }
        endOfChars = false
    }
    
    public func push(_ str: String) {
        push(MkdownInput(str))
    }
    
    public func push(_ reader: MkdownInput) {
        stack.append(reader)
        endOfChars = false
    }
    
    public func popIfEnded() {
        while !stack.isEmpty && mkdownInput.endOfChars {
            stack.removeLast()
        }
    }
    
    /// Read the next character, setting a flag at the end of all available input. 
    public func nextChar() -> Character? {
        
        guard !stack.isEmpty else {
            endOfChars = true
            return nil
        }
        
        return mkdownInput.nextChar()
        
    }
    
    public func setIndex(_ target: MkdownInput.MkdownInputPosition,
                         to: MkdownInput.MkdownInputPosition) {
        mkdownInput.setIndex(target, to: to)
    }
    
    public func indexAfter(_ target: MkdownInput.MkdownInputPosition) {
        mkdownInput.indexAfter(target)
    }
    
    public func indexBefore(_ target: MkdownInput.MkdownInputPosition) {
        mkdownInput.indexBefore(target)
    }
    
    public func getLine() -> String {
        return mkdownInput.getLine()
    }
    
    public func getText() -> String {
        return mkdownInput.getText()
    }
    
    public func getMath() -> String {
        return mkdownInput.getMath()
    }
    
    public func getString(from: MkdownInput.MkdownInputPosition,
                          to: MkdownInput.MkdownInputPosition) -> String {
        return mkdownInput.getString(from: from, to: to)
    }
    
    public var mkdownInput: MkdownInput {
        if stack.isEmpty {
            return MkdownInput()
        } else {
            return stack[stack.count - 1]
        }
    }
    
    public var count: Int { return mkdownInput.count }
    
    public func display() {
        print(" ")
        print("MkdownInputStack")
        print("  - Stack count = \(stack.count)")
        print("  - Top of Stack count = \(mkdownInput.count)")
        print("  - End of Chars? \(endOfChars)")
    }
    
}
