//
//  MkdownOptions.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 7/15/21.
//
//  Copyright © 2021 - 2023 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

/// Various options to control the conversion of Markdown to HTML. 
public class MkdownOptions {
    
    public var wikiLinks = WikiLinkDisplay()
    public var shortID = ""
    public var mathJax = false
    public var localMj = true
    public var localMjUrl: URL?
    public var curlyApostrophes = true
    public var extLinksOpenInNewWindows = false
    public var checkBoxMessageHandlerName = ""
    public var inlineHashtags = false
    public var flattenImageLinks = false
    
    public init() {
        
    }
    
    public func getHtmlScript() -> String {
        var js = ""
        var mjUrlString = ""
        if mathJax {
            if localMj && localMjUrl != nil {
                mjUrlString = localMjUrl!.absoluteString
            } else {
                mjUrlString = "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"
            }
            js.append("window.MathJax = { \n")
            js.append("    tex: { \n")
            js.append("      tags: 'ams' \n")
            js.append("    } \n")
            js.append("  }; \n")
        }
        var script = ""
        if !js.isEmpty {
            script.append("<script type=\"text/javascript\"> \n")
            script.append(js)
            script.append("</script> \n")
            if mathJax {
                script.append("<script type=\"text/javascript\" id=\"MathJax-script\" async src=\"\(mjUrlString)\"> \n")
                script.append("</script>")
            }
        }
        return script
    }
    
}
