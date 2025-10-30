//
//  MkdownContext.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 3/22/20.

//  Copyright © 2020 - 2024 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

/// A protocol for performing various operations that require some context of other Notes
/// within a Collection, in order to generate some Markdown or HTML to be inserted into
/// the display of a Note whose Markdown is being parsed.
public protocol MkdownContext {
    
    /// Identify the note that is about to be parsed. 
    /// - Parameters:
    ///   - id: The common ID for the note, to be used by Notenik. 
    ///   - text: A textual representation of the note ID, to be read by humans.
    ///   - fileName: The common filename for the note. 
    ///   - shortID: The short, minimal, ID for the note. 
    func identifyNoteToParse(id: String, text: String, fileName: String, shortID: String)
    
    /// Expose the usage of a Markdown command found within the page.
    func exposeMarkdownCommand(_ command: String)
    
    /// Expose each image link found within the Markdown. 
    func exposeImageLink(original: String, modified: String)
    
    /// Collect embedded hash tags found within the Markdown. 
    func addHashTag(_ tag: String) -> String
    
    /// Given the title of one Note, return the (possibly renamed) title to be used. 
    func mkdownWikiLinkLookup(linkText: String) -> WikiLinkTarget?
    
    /// Generate HTML for a Calendar showing the Notes.
    func mkdownCalendar(mods: String) -> String
    
    /// Return a Table of Contents for the Collection, formatted in HTML. 
    func mkdownCollectionTOC(levelStart: Int, levelEnd: Int, details: Bool) -> String
    
    /// Return an index to the Collection, formatted in HTML.
    func mkdownIndex() -> String
    
    /// Generate a page that will randomly navigate to another page. 
    func mkdownRandomNote(klassNames: String) -> String
    
    /// Return a search page for the Collection, formatted in HTML.
    func mkdownSearch(siteURL: String) -> String
    
    /// Generate javascript to sort the following table.
    func mkdownTableSort() -> String
    
    /// Return a tags outline of the collection, formatted in HTML.
    func mkdownTagsOutline(mods: String) -> String
    
    /// Return a list of children, with teasers formatted in HTML. 
    func mkdownTeasers() -> String
    
    /// Return a tags cloud of the collection, formatted in HTML.
    func mkdownTagsCloud(mods: String) -> String
    
    /// Include another Note, or an external file. 
    func mkdownInclude(item: String, style: String) -> String?
    
    /// Generate a bibliography from Notes following this one. 
    func mkdownBibliography() -> String
    
    func mkdownAuthorsTable() -> String
    
    /// Provide links to file attachments. 
    func mkdownAttachments() -> String
    
}
