//
//  MkdownOptions.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 7/15/21.
//
//  Copyright © 2021 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

public class MkdownOptions {
    
    let interNoteDomain = "https://ntnk.app/"
    
    public var wikiLinkPrefix = ""
    public var wikiLinkSuffix = ""
    public var wikiLinkFormatting: WikiLinkFormat = .common
    
    public var mathJax = false
    public var localMj = true
    public var localMjUrl: URL?
    public var curlyApostrophes = true
    public var extLinksOpenInNewWindows = false
    
    public init() {
        wikiLinkPrefix = interNoteDomain
    }
    
    public func getHtmlScript() -> String {
        guard mathJax else { return "" }
        var mjUrlString = ""
        if localMj && localMjUrl != nil {
            mjUrlString = localMjUrl!.absoluteString
        } else {
            mjUrlString = "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"
        }
        
        var script = ""
        script.append("<script type=\"text/javascript\"> \n")
        script.append("window.MathJax = { \n")
        script.append("    tex: { \n")
        script.append("      tags: 'ams' \n")
        script.append("    } \n")
        script.append("  }; \n")
        script.append("</script> \n")
        script.append("<script type=\"text/javascript\" id=\"MathJax-script\" async src=\"\(mjUrlString)\"> \n")
        script.append("</script>")
        return script
    }
    
}
