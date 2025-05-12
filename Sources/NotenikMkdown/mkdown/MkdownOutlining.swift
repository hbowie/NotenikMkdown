//
//  MkdownOutlining.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 5/21/23.
//
//  Copyright © 2023 - 2025 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

enum MkdownOutlining {
    case none
    case bullets
    case headings
    case headingsPlusBullets
    
    var noBullets: Bool {
        return self != .bullets && self != .headingsPlusBullets
    }
    
    var forBullets: Bool {
        return self == .bullets || self == .headingsPlusBullets
    }
    
    var forHeadings: Bool {
        return self == .headings || self == .headingsPlusBullets
    }
}
