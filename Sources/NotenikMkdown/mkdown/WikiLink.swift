//
//  WikiLink.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 10/1/21.
//
//  Copyright © 2021 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

import NotenikUtils

public class WikiLink: Comparable, CustomStringConvertible, Equatable, Identifiable {
    
    let sep = " ==> "
    
    // From Title
    var _ft = ""
    public var fromTitle: String {
        get {
            return _ft
        }
        set {
            _ft = newValue
            _fc = StringUtils.toCommon(newValue)
        }
    }
    
    // From Title reduced to common format.
    var _fc = ""
    public var fromCommon: String {
        return _fc
    }
    
    // Original target Note title.
    var _to = ""
    public var originalTarget: String {
        get {
            return _to
        }
        set {
            _to = newValue
            _tc = StringUtils.toCommon(newValue)
        }
    }
    
    // Updated target Note title.
    var _tu = ""
    public var updatedTarget: String {
        get {
            return _tu
        }
        set {
            _tu = newValue
            if !newValue.isEmpty {
                _tc = StringUtils.toCommon(newValue)
            }
        }
    }
    
    // Target Note title (original or updated) reduced to common format.
    var _tc = ""
    public var targetCommon: String {
        return _tc
    }
    
    public var bestTarget: String {
        if !updatedTarget.isEmpty {
            return updatedTarget
        } else {
            return originalTarget
        }
    }
    
    public var targetFound = false
    
    public var id: String {
        return fromCommon + sep + targetCommon
    }
    
    public var sortKey: String {
        return fromCommon + sep + targetCommon
    }
    
    public var description: String {
        if !updatedTarget.isEmpty && updatedTarget != originalTarget {
            return "\(fromTitle)\(sep)\(originalTarget) (now \(updatedTarget))"
        } else {
            return "\(fromTitle)\(sep)\(originalTarget)"
        }
    }
    
    public init() {
        
    }
    
    public func display() {
        print(" ")
        print("  WikiLink.display")
        print("    - From Title = \(fromTitle)")
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
