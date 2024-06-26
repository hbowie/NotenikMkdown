//
//  WikiLinkDisplay.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 5/2/23.
//
//  Copyright © 2023 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

import NotenikUtils

public class WikiLinkDisplay {
    
    public var interNoteDomain = "https://ntnk.app/"
    
    public var format: WikiLinkFormat = .common
    public var prefix = "https://ntnk.app/"
    public var suffix = ""
    
    public init() {
        
    }
    
    public init(format: WikiLinkFormat, prefix: String, suffix: String) {
        self.format = format
        self.prefix = prefix
        self.suffix = suffix
    }
    
    public func resetToDefaults() {
        format = .common
        prefix = interNoteDomain
        suffix = ""
    }
    
    public func set(format: WikiLinkFormat, prefix: String, suffix: String) {
        self.format = format
        self.prefix = prefix
        self.suffix = suffix
    }
    
    public func copy() -> WikiLinkDisplay {
        return WikiLinkDisplay(format: format, prefix: prefix, suffix: suffix)
    }
    
    public func copyTo(another: WikiLinkDisplay) {
        another.format = self.format
        another.prefix = self.prefix
        another.suffix = self.suffix
    }
    
    public func assembleWikiLink(target: WikiLinkTarget) -> String {
        if prefix.isEmpty && format == .fileName && suffix == ".html" && target.hasPath {
            return "../" + target.formatWikiLink(format: format) + suffix
        } else {
            return prefix + target.formatWikiLink(format: format) + suffix
        }
    }
    
    /// Create a wiki link, based on the wiki parms.
    public func assembleWikiLink(idBasis: String) -> String {
        return prefix + formatWikiLink(idBasis) + suffix
    }
    
    /// Convert a title to something that can be used in a link.
    public func formatWikiLink(_ idBasis: String) -> String {
        switch format {
        case .common:
            return StringUtils.toCommon(idBasis)
        case .fileName:
            return StringUtils.toCommonFileName(idBasis)
        case .mmdID:
            return StringUtils.autoID(idBasis)
        }
    }
    
    public func display() {
        print("WikiLinkDisplay format: \(prefix) + \(format) + \(suffix)")
    }
}
