//
//  NotePointerList.swift
//  NotenikLib
//
//  Created by Herb Bowie on 10/3/21.
//
//  Copyright © 2021 - 2023 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

import NotenikUtils

/// A list of pointers to Notes.
public class WikiLinkTargetList: CustomStringConvertible, Collection, Sequence {

    public typealias Element = WikiLinkTarget
    
    public var list: [WikiLinkTarget] = []
    
    public var startIndex: Int {
        return 0
    }
    
    public var endIndex: Int {
        return list.count
    }
    
    public func index(after i: Int) -> Int {
        return i + 1
    }
    
    public subscript(position: Int) -> WikiLinkTarget {
        return list[position]
    }
    
    /// Use a pair of semicolons as the separator between titles.
    public var description: String {
        return value
    }
    
    public var value: String {
        var str = ""
        for pointer in list {
            str.append(pointer.pathSlashItem)
            str.append(";; ")
        }
        return str
    }
    
    public init() {
        
    }
    
    public func clear() {
        list = []
    }
    
    /// Examine a line of text, separating it into Note identifiers, with
    /// paired semicolons serving as the separators.
    public func append(_ line: String) {
        var pendingSpaces = 0
        var semiStash = ""
        var nextNoteIdBasis = ""
        for c in line {
            if c == ";" {
                semiStash.append(c)
                if semiStash == ";;" {
                    if !nextNoteIdBasis.isEmpty {
                        add(noteIdBasis: nextNoteIdBasis)
                        nextNoteIdBasis = ""
                    }
                    semiStash = ""
                    pendingSpaces = 0
                }
                continue
            }
            if semiStash == ";" {
                nextNoteIdBasis.append(semiStash)
                semiStash = ""
            }
            if c.isWhitespace {
                pendingSpaces += 1
                continue
            }
            if pendingSpaces > 0 {
                nextNoteIdBasis.append(" ")
                pendingSpaces = 0
            }
            nextNoteIdBasis.append(c)
        }
        if !nextNoteIdBasis.isEmpty {
            add(noteIdBasis: nextNoteIdBasis)
        }
    }
    
    /// Add another title, but don't allow duplicate IDs, and keep the list sorted
    /// by the lowest common denominator representation.
    /// - Parameter title: The Title of a Note.
    public func add(noteIdBasis: String) {
        let newPointer = WikiLinkTarget(noteIdBasis)
        var index = 0
        while index < list.count && newPointer > list[index] {
            index += 1
        }
        if index >= list.count {
            list.append(newPointer)
        } else if newPointer == list[index] {
            return
        } else {
            list.insert(newPointer, at: index)
        }
    }
    
    public func remove(noteIdBasis: String) {
        let pointerToRemove = WikiLinkTarget(noteIdBasis)
        var index = 0
        while index < list.count && pointerToRemove.pathSlashID != list[index].pathSlashID {
            index += 1
        }
        if index < list.count {
            list.remove(at: index)
        }
    }
    
    /// Factory method to return an iterator.
    public func makeIterator() -> WikiLinkTargetIterator {
        return WikiLinkTargetIterator(self)
    }
    
    public func display(indentLevels: Int = 0) {
        
        StringUtils.display("\(list.count)",
                            label: "count",
                            blankBefore: true,
                            header: "NotePointerList",
                            sepLine: false,
                            indentLevels: indentLevels)
        for pointer in list {
            pointer.display(indentLevels: indentLevels + 1)
        }
    }
    
    /// The Iterator.
    public class WikiLinkTargetIterator: IteratorProtocol {

        public typealias Element = WikiLinkTarget
        
        var pointers: WikiLinkTargetList
        
        var index = 0
        
        public init(_ pointers: WikiLinkTargetList) {
            self.pointers = pointers
        }
        
        public func next() -> WikiLinkTarget? {
            guard index >= 0 && index < pointers.list.count else { return nil }
            let nextPointer = pointers.list[index]
            index += 1
            return nextPointer
        }
    }
}
