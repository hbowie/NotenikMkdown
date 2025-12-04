//
//  WikiLinkList.swift
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

/// A list of the wiki links found by the Mkdown Parser as part of its parse operation.
public class WikiLinkList {
    
    public var links: [WikiLink] = []
    
    public init() {
        
    }
    
    public func addLink(fromPath: String, fromTitle: String, targetFound: Bool, wikiLink: WikiLink) {
        let newLink = WikiLink()
        let fromTarget = WikiLinkTarget(path: fromPath, item: fromTitle)
        newLink.fromTarget = fromTarget
        newLink.originalTarget = wikiLink.originalTarget
        newLink.updatedTarget = wikiLink.updatedTarget
        newLink.targetFound = targetFound
        addLink(newLink)
    }
    
    public var count: Int {
        return links.count
    }
    
    public var isEmpty: Bool {
        return links.isEmpty
    }
    
    public func addList(moreLinks: WikiLinkList) {
        for wikiLink in moreLinks.links {
            addLink(wikiLink)
        }
    }
    
    public func addLink(_ link: WikiLink) {
        for existingLink in links {
            guard existingLink != link else {
                return
            }
        }
        links.append(link)
    }
    
    public func display() {
        print(" ")
        print("WikiLinkList.display with \(links.count) links")
        for link in links {
            link.display()
        }
    }
    
}
