//
//  MkdownContext.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 3/22/20.

//  Copyright © 2020 - 2021 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

/// A protocol for looking up a title and transforming it to a different value.
public protocol MkdownContext {
    
    /// Given the title of one Note, return the (possibly renamed) title to be used. 
    func mkdownWikiLinkLookup(linkText: String) -> String?
    
    /// Return a Table of Contents for the Collection, formatted in HTML. 
    func mkdownCollectionTOC(levelStart: Int, levelEnd: Int) -> String
    
    /// Return an index to the Collection, formatted in HTML.
    func mkdownIndex() -> String
    
    /// Return a tags outline of the collection, formatted in HTML.
    func mkdownTagsOutline() -> String
    
}
