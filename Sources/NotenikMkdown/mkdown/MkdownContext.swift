//
//  MkdownContext.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 3/22/20.

//  Copyright © 2020 - 2022 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

/// A protocol for looking up a title and transforming it to a different value.
public protocol MkdownContext {
    
    /// Set the Title of the Note whose Markdown text is to be parsed.
    func setTitleToParse(title: String)
    
    /// Given the title of one Note, return the (possibly renamed) title to be used. 
    func mkdownWikiLinkLookup(linkText: String) -> WikiLinkTarget?
    
    /// Return a Table of Contents for the Collection, formatted in HTML. 
    func mkdownCollectionTOC(levelStart: Int, levelEnd: Int) -> String
    
    /// Return an index to the Collection, formatted in HTML.
    func mkdownIndex() -> String
    
    /// Return a search page for the Collection, formatted in HTML.
    func mkdownSearch(siteURL: String) -> String
    
    /// Return a tags outline of the collection, formatted in HTML.
    func mkdownTagsOutline(mods: String) -> String
    
    /// Return a list of children, with teasers formatted in HTML. 
    func mkdownTeasers() -> String
    
    /// Return a tags cloud of the collection, formatted in HTML.
    func mkdownTagsCloud(mods: String) -> String
    
    /// Include another Note, or an external file. 
    func mkdownInclude(item: String, style: String) -> String?
    
}
