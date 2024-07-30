//
//  MkdownCounts.swift
//
//  Created by Herb Bowie on 5/28/20.
//  Copyright © 2020 Herb Bowie (https://powersurgepub.com)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

public class MkdownCounts {
    public var size = 0
    public var lines = 0
    public var words = 0
    public var text = 0
    public var averageWordLength: Double {
        if text > 0 && words > 0 {
            return Double(text) / Double (words)
        } else {
            return 0
        }
    }
    
    public init() {
        
    }
    
    public func display() {
        print("MkdownCounts.display")
        print("  - size = \(size)")
        print("  - lines = \(lines)")
        print("  - words = \(words)")
        print("  - text = \(text)")
    }
}
