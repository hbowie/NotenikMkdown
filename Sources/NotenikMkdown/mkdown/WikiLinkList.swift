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

public class WikiLinkList {
    
    public var links: [WikiLink] = []
    
    public init() {
        
    }
    
    public func display() {
        print(" ")
        print("WikiLinkList.display")
        for link in links {
            link.display()
        }
    }
    
}
