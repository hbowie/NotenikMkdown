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

public class WikiLink {
    public var fromTitle = ""
    public var originalTarget = ""
    public var updatedTarget = ""
    public var targetFound = false
    
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
}
