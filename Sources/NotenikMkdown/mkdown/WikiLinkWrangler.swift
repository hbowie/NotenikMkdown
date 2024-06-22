//
//  WikiLinkWrangler.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 5/1/23.
//
//  Copyright © 2023 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

import NotenikUtils

/// Generate useful markup from wiki links. 
public class WikiLinkWrangler {
    
    var options: MkdownOptions!
    var context: MkdownContext?
    
    public init(options: MkdownOptions, context: MkdownContext?) {
        self.context = context
        self.options = options
    }
    
    /// For certain fields, generate special HTML when needed.
    /// - Parameters:
    ///   - def: The definition of the field.
    ///   - parms: The display parameters to be used.
    ///   - markedup: The instance of Markedup to be used to generate the output.
    public func targetsToHTML(properLabel: String, targets: WikiLinkTargetList, markedup: Markedup) {
        
        guard targets.count > 0 else { return }
        
        markedup.startDetails(summary: properLabel)
        markedup.startUnorderedList(klass: nil)
        for target in targets {
            markedup.startListItem()
            markedup.link(text: target.pathSlashItem,
                          path: assembleWikiLink(target: target))
            markedup.finishListItem()
        }
        markedup.finishUnorderedList()
        markedup.finishDetails()
    }
    
    public func assembleWikiLink(title: String, wikiLinkList: WikiLinkList?) -> String {

        let wikiLink = WikiLink()
        wikiLink.setOriginalTarget(title)
        if context != nil {
            let lookedUp = context!.mkdownWikiLinkLookup(linkText: title)
            if lookedUp == nil {
                wikiLink.targetFound = false
            } else {
                wikiLink.updatedTarget = lookedUp!
                wikiLink.targetFound = true
            }
        }
        if wikiLinkList != nil {
            wikiLinkList!.links.append(wikiLink)
        }
        return assembleWikiLink(target: wikiLink.bestTarget)
    }
    
    public func assembleWikiLink(target: WikiLinkTarget) -> String {
        return options.wikiLinks.prefix
            + target.formatWikiLink(format: options.wikiLinks.format)
            + options.wikiLinks.suffix
    }
    
    /// Create a wiki link, based on the wiki parms.
    public func assembleWikiLink(title: String) -> String {
        return options.wikiLinks.prefix
            + formatWikiLink(title)
            + options.wikiLinks.suffix
    }
    
    /// Convert a title to something that can be used in a link.
    public func formatWikiLink(_ title: String) -> String {
        switch options.wikiLinks.format {
        case .common:
            return StringUtils.toCommon(title)
        case .fileName:
            return StringUtils.toCommonFileName(title)
        case .mmdID:
            return StringUtils.autoID(title)
        }
    }
}
