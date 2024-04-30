//
//  WikiLink.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 10/1/21.
//
//  Copyright © 2021 - 2022 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

import NotenikUtils

/// A link from one Note to another. 
public class WikiLink: Comparable, CustomStringConvertible, Equatable, Identifiable {
    
    let sep = " ==> "
    
    public init() {
        
    }
    
    // From Title
    var _ft = WikiLinkTarget()
    public var fromTarget: WikiLinkTarget {
        get {
            return _ft
        }
        set {
            _ft = newValue
        }
    }
    
    public func setFrom(path: String, item: String) {
        fromTarget = WikiLinkTarget(path: path, item: item)
    }
    
    // Original target Note id.
    var _to = WikiLinkTarget()
    public var originalTarget: WikiLinkTarget {
        get {
            return _to
        }
        set {
            _to = newValue
        }
    }
    
    public func setOriginalTarget(_ linkText: String) {
        originalTarget = WikiLinkTarget(linkText)
    }
    
    // Updated target Note title.
    var _tu = WikiLinkTarget()
    public var updatedTarget: WikiLinkTarget {
        get {
            return _tu
        }
        set {
            _tu = newValue
        }
    }
    
    public func setUpdatedTarget(_ linkText: String) {
        updatedTarget = WikiLinkTarget(linkText)
    }
    
    // Target Note title (original or updated) reduced to common format.
    // var _tc = ""
    // public var targetCommon: String {
    //     return _tc
    // }
    
    public var bestTarget: WikiLinkTarget {
        if !updatedTarget.isEmpty {
            return updatedTarget
        } else {
            return originalTarget
        }
    }
    
    public var targetFound = false
    
    public var id: String {
        return fromTarget.pathSlashID + sep + bestTarget.pathSlashID
    }
    
    public var sortKey: String {
        return fromTarget.pathSlashID + sep + bestTarget.pathSlashID
    }
    
    public var description: String {
        if !updatedTarget.isEmpty && updatedTarget != originalTarget {
            return "\(fromTarget)\(sep)\(originalTarget) (now \(updatedTarget))"
        } else {
            return "\(fromTarget)\(sep)\(originalTarget)"
        }
    }
    
    public func display() {
        print(" ")
        print("  WikiLink.display")
        print("    - From Target = \(fromTarget)")
        print("    - Original Target = \(originalTarget)")
        print("    - Updated  Target = \(updatedTarget)")
        print("    - Target found? \(targetFound)")
    }
    
    public static func < (lhs: WikiLink, rhs: WikiLink) -> Bool {
        return lhs.sortKey < rhs.sortKey
    }
    
    public static func == (lhs: WikiLink, rhs: WikiLink) -> Bool {
        return lhs.sortKey == rhs.sortKey
    }
}
