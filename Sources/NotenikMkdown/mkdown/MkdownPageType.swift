//
//  MkdownPageType.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 4/6/23.
//
//  Copyright © 2023 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

public enum MkdownPageType {
    case main
    case header
    case footer
    case nav
    case metadata
    case search
    
    public func excludeFromBook(epub: Bool) -> Bool {
        if self == .main { return false }
        if self == .search && epub { return true }
        return true
    }
    
    public func includeInBook(epub: Bool) -> Bool {
        if self == .main { return true }
        if self == .search && !epub { return true }
        return false
    }

}
