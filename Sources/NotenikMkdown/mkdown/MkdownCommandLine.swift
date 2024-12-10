//
//  MkdownCommandLine.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 6/21/24.
//
//  Copyright © 2024 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

import NotenikUtils

public class MkdownCommandLine {
    
    var info = MkdownCommandInfo()
    
    public init() {

    }
    
    public func checkLine(_ line: String) -> MkdownCommandInfo {
        info = MkdownCommandInfo()
        if line.hasPrefix("{{")
                || line.hasPrefix("[")
                || line.hasPrefix("{:")
                || line.hasPrefix("![[") {
            checkForCommandClosing(line)
        }
        return info
    }
    
    /// Performed as part of Finish Line processing.
    func checkForCommandClosing(_ line: String) {
        
        var prefixComplete = false
        var commandComplete = false
        var styleComplete = false
        var modsComplete = false
        var digit1: Character = " "
        var digit2: Character = " "
        for char in line {
            
            if !prefixComplete {
                if char == "[" || char == "{" || char == ":" || char == "!" {
                    info.prefix.append(char)
                } else {
                    prefixComplete = true
                    if info.prefix == "![[" {
                        info.command = "include"
                        commandComplete = true
                        styleComplete = true
                    }
                }
            }
            
            if prefixComplete && !commandComplete {
                if char == "]" || char == "}" {
                    commandComplete = true
                    styleComplete = true
                    modsComplete = true
                } else if char == ":" {
                    commandComplete = true
                    styleComplete = true
                } else if char == "-" && info.command == "include" {
                    commandComplete = true
                } else if !char.isWhitespace && char != "-" {
                    info.command.append(char.lowercased())
                }
            }
            
            if prefixComplete && commandComplete && !styleComplete {
                if char == "]" || char == "}" {
                    styleComplete = true
                    modsComplete = true
                } else if char == ":" {
                    styleComplete = true
                } else if !char.isWhitespace && char != "-" {
                    info.includeStyle.append(char.lowercased())
                }
            }
            
            if prefixComplete && commandComplete && styleComplete && info.command == MkdownConstants.quoteFromCmd {
                if info.parms.isEmpty && (char.isWhitespace || char == ":") {
                    // skip leading spacers
                } else if char == "]" || char == "}" {
                    // skip trailing delimiters
                } else {
                    info.parms.append(char)
                }
            }
            
            if prefixComplete && commandComplete && styleComplete && 
                (info.command == MkdownConstants.bylineCmd || info.command == "by") {
                if info.parms.isEmpty && (char.isWhitespace || char == ":") {
                    // skip leading spacers
                } else if char == "]" || char == "}" {
                    // skip trailing delimiters
                } else {
                    info.parms.append(char)
                }
            }
            
            if prefixComplete && commandComplete && styleComplete && !modsComplete {
                if char == ":" {
                    // do nothing
                } else if char == "]" || char == "}" {
                    modsComplete = true
                } else if char.isWhitespace && info.mods.isEmpty {
                    // do nothing
                } else {
                    info.mods.append(char)
                    if char == "-" {
                        // do nothing
                    } else if char.isNumber && digit1 != " " {
                        digit2 = char
                    } else if char.isNumber {
                        digit1 = char
                    }
                }
            }
            
            if prefixComplete && commandComplete && styleComplete && modsComplete {
                if !char.isWhitespace {
                    info.suffix.append(char)
                }
            }
            
        } // end of chars in line
        
        // See if we have a good prefix and a matching suffix.
        guard (info.prefix == "{:" && info.suffix == "}")
                || (info.prefix == "[[" && info.suffix == "]]")
                || (info.prefix == "[" && info.suffix == "]")
                || (info.prefix == "{{" && info.suffix == "}}")
                || (info.prefix == "![[" && info.suffix == "]]") else {
            return
        }
        
        switch info.command {
        case MkdownConstants.attachmentsCmd:
            info.lineType = .attachments
            info.validCommand = true
        case MkdownConstants.biblioCmd:
            info.lineType = .biblio
            info.validCommand = true
        case MkdownConstants.calendarCmd:
            info.lineType = .calendar
            info.validCommand = true
        case MkdownConstants.captionCmd:
            info.lineType = .caption
            info.validCommand = true
        case MkdownConstants.endfigureCmd:
            info.lineType = .endFigure
            info.validCommand = true
        case MkdownConstants.figureCmd:
            info.lineType = .figure
            info.validCommand = true
        case MkdownConstants.collectionTocCmd:
            info.lineType = .tocForCollection
            info.tocLevelStart = digit1
            if digit2.isNumber {
                info.tocLevelEnd = digit2
            }
            info.validCommand = true
        case MkdownConstants.tocCmd:
            info.lineType = .tableOfContents
            info.tocLevelStart = digit1
            if digit2.isNumber {
                info.tocLevelEnd = digit2
            }
            info.validCommand = true
        case MkdownConstants.indexCmd:
            info.lineType = .index
            info.validCommand = true
        case MkdownConstants.quoteFromCmd:
            info.lineType = .quoteFrom
            info.validCommand = true
        case MkdownConstants.bylineCmd, "by":
            info.lineType = . byline
            info.validCommand = true
        case MkdownConstants.tagsCloudCmd:
            info.lineType = .tagsCloud
            info.validCommand = true
        case MkdownConstants.tagsOutlineCmd:
            info.lineType = .tagsOutline
            info.validCommand = true
        case MkdownConstants.includeCmd:
            info.lineType = .include
            info.validCommand = true
        case MkdownConstants.teasersCmd:
            info.lineType = .teasers
            info.validCommand = true
        case MkdownConstants.searchCmd:
            info.lineType = .search
            info.validCommand = true
        case MkdownConstants.sortTableCmd:
            info.lineType = .sortTable
            info.validCommand = true
        case MkdownConstants.headerCmd:
            info.lineType = .header
            info.validCommand = true
        case MkdownConstants.footerCmd:
            info.lineType = .footer
            info.validCommand = true
        case MkdownConstants.navCmd:
            info.lineType = .nav
            info.validCommand = true
        case MkdownConstants.metadataCmd:
            info.lineType = .metadata
            info.validCommand = true
        case MkdownConstants.randomCmd:
            info.lineType = .random
            info.validCommand = true
        case MkdownConstants.outlineBulletsCmd:
            info.lineType = .outlineBullets
            info.validCommand = true
        case MkdownConstants.outlineHeadingsCmd:
            info.lineType = .outlineHeadings
            info.validCommand = true
        case MkdownConstants.pclassCmd:
            info.lineType = .pClass
            info.validCommand = true
        default:
            break
        }
    }
}
