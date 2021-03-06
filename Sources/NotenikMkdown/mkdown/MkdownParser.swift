//
//  MkdownParser.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 2/25/20.
//  Copyright © 2020 - 2021 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

import NotenikUtils

/// A class to parse Mardkown input and do useful things with it. To use:
/// - Initialize a new MkdownParser object.
/// - Set the mkdown source, if not set as part of initialization.
/// - Set the wiki link formatting, if needed.
/// - Call the parse method.
/// - Retrieve the generated HTML from the html variable.

public class MkdownParser {
    
    // ===============================================================
    //
    // OVERALL PARSING STRATEGY
    //
    // Initialization: Capture the Markdown text to be parsed.
    //
    // Phase 1: Parse the text and break it into lines, identifying
    //          the type of each line, along with other metadata.
    //
    // Phase 2: Go through the lines, generating HTML output.
    // ===============================================================
    
    var mkdown:    String! = ""
    
    public var options = MkdownOptions()
    
    public var mkdownContext: MkdownContext?
    
    var nextIndex: String.Index
    
    var nextLine = MkdownLine()
    var lastLine = MkdownLine()
    var lastNonBlankLine = MkdownLine()
    var lastBlankLine = MkdownLine()
    var lastDefLine = MkdownLine()
    var nonDefCount = 3
    
    var lineIndex = -1
    var startLine: String.Index
    var startText: String.Index
    var endLine:   String.Index
    var endText:   String.Index
    var phase:     MkdownLinePhase = .leadingPunctuation
    var spaceCount = 0
    
    var leadingNumber = false
    var leadingNumberAndPeriod = false
    var leadingNumberPeriodAndSpace = false
    
    var leadingBullet = false
    
    var leadingColon = false
    
    var leadingLeftAngleBracket = false
    var leadingLeftAngleBracketAndSlash = false
    var possibleTagPending = false
    var possibleTag = ""
    var goodTag = false
    var following = false
    var followingType: MkdownLineType = .ordinaryText
    
    var openHTMLblockTag = ""
    var openHTMLblock = false
    
    var startNumber: String.Index
    var startBullet: String.Index
    var startColon:  String.Index
    
    var linkLabelPhase: LinkLabelDefPhase = .na
    var angleBracketsUsed = false
    var titleEndChar: Character = " "
    
    var refLink = RefLink()
    
    var footnote = MkdownFootnote()
    var withinFootnote = false
    
    var citation = MkdownCitation()
    var withinCitation = false
    
    var headingNumbers = [0, 0, 0, 0, 0, 0, 0]
    
    var indentToCode = false
    
    var codeFenced = false
    var codeFenceChar: Character = " "
    var codeFenceRepeatCount = 0
    
    var mathLineStart = ""
    var mathLineEnd = ""
    var mathLineEndTrailingWhiteSpace = false
    var mathLineValidStart: Bool {
        return mathLineStart == "$$" || mathLineStart == "\\\\["
    }
    var startMath: String.Index
    var endMath:   String.Index
    
    public var counts = MkdownCounts()
    
    /// A static utility function to convert markdown to HTML and write it to an instance of Markedup. 
    public static func markdownToMarkedup(markdown: String,
                                          options: MkdownOptions,
                                          mkdownContext: MkdownContext?,
                                          writer: Markedup) {
        let md = MkdownParser(markdown, options: options, context: mkdownContext)
        md.parse()
        writer.append(md.html)
    }
    
    
    // ===========================================================
    //
    // Initialization.
    //
    // ===========================================================

    
    /// Initialize with an empty string.
    public init() {
        nextIndex = mkdown.startIndex
        startText = nextIndex
        startLine = nextIndex
        endLine = nextIndex
        endText = nextIndex
        startNumber = nextIndex
        startBullet = nextIndex
        startColon = nextIndex
        startMath = nextIndex
        endMath = nextIndex
    }
    
    public convenience init(options: MkdownOptions) {
        self.init()
        self.options = options
    }
    
    /// Initialize with a string that will be copied.
    public convenience init(_ mkdown: String, options: MkdownOptions, context: MkdownContext? = nil) {
        self.init()
        self.mkdown = mkdown
        self.options = options
        self.mkdownContext = context
    }
    
    /// Try to initialize by reading input from a URL.
    public convenience init?(_ url: URL) {
        self.init()
        do {
            try mkdown = String(contentsOf: url)
        } catch {
            print("Error is \(error)")
            return nil
        }
    }
    
    /// If using wiki-style links, set the formatting options before performing the parse operation.
    public func setWikiLinkFormatting(prefix: String,
                               format: WikiLinkFormat,
                               suffix: String,
                               context: MkdownContext? = nil) {
        options.wikiLinkPrefix = prefix
        options.wikiLinkFormatting = format
        options.wikiLinkSuffix = suffix
        mkdownContext = context
    }
    
    /// Perform the parsing.
    public func parse() {
        
        counts.size = mkdown.count
        counts.lines = 0
        counts.words = 0
        counts.text = 0
        
        mdToLines()
        linesOut()
    }
    
    // ===========================================================
    //
    // Phase 1 - Parse the input block of Markdown text, and
    // break down into lines.
    //
    // ===========================================================
    
    /// Make our first pass through the Markdown, identifying basic info about each line.
    func mdToLines() {
        
        withinFootnote = false
        withinCitation = false
        nextIndex = mkdown.startIndex
        beginLine()
        
        while nextIndex < mkdown.endIndex {
             
            // Get the next character and adjust indices
            let char = mkdown[nextIndex]
            
            /* Following code can be uncommented for debugging.
            print("char = \(char)")
            print("  - phase = \(phase)")
            print("  - repeating char = \(nextLine.repeatingChar)")
            print("  - repeat count = \(nextLine.repeatCount)")
            print("  - only repeating? \(nextLine.onlyRepeating)")
            print("  - only repeating and spaces? \(nextLine.onlyRepeatingAndSpaces)")
            print("  - possible tag pending? \(possibleTagPending)")
            print("  - open HTML block? \(openHTMLblock)")
            print("  - leading number? \(leadingNumber)")
            print("  - leading number and period? \(leadingNumberAndPeriod)")
            print("  - leading number, period and space? \(leadingNumberPeriodAndSpace)")
            print("  - leading bullet? \(leadingBullet)")
            print("  - leading colon? \(leadingColon)")
            print("  - following? \(following)")
            print("  - following type = \(followingType)")
             */
            
            let lastIndex = nextIndex
            nextIndex = mkdown.index(after: nextIndex)
            lineIndex += 1
            
            // Deal with end of line
            if char.isNewline {
                nextLine.endsWithNewline = true
                finishLine()
                beginLine()
                continue
            }
            
            endLine = nextIndex
            
            // Check for a line consisting of a repetition of a single character.
            if (char == "-" || char == "=" || char == "*" || char == "_" || char == "`" || char == "~")
                && (nextLine.repeatingChar == " " || nextLine.repeatingChar == char) {
                nextLine.repeatingChar = char
                nextLine.repeatCount += 1
            } else if char == " " {
                nextLine.onlyRepeating = false
            } else if char == ">" && phase == .leadingPunctuation {
                // Blockquotes make no difference
            } else {
                nextLine.onlyRepeating = false
                nextLine.onlyRepeatingAndSpaces = false
            }
            
            // Check for an HTML block
            if lineIndex == 0 && char == "<" {
                leadingLeftAngleBracket = true
                possibleTagPending = true
            } else if possibleTagPending {
                if char.isWhitespace || char == ">" {
                    possibleTagPending = false
                    switch possibleTag {
                    case "a":
                        goodTag = true
                    case "h1", "h2", "h3", "h4", "h5", "h6":
                        goodTag = true
                    case "div", "pre", "p", "table":
                        goodTag = true
                    case "ol", "ul", "dl", "dt", "li":
                        goodTag = true
                    case "hr", "blockquote", "address":
                        goodTag = true
                    case "!--":
                        goodTag = true
                    default:
                        goodTag = false
                    }
                } else if lineIndex == 1 && char == "/" {
                    leadingLeftAngleBracketAndSlash = true
                } else {
                    possibleTag.append(char)
                    if possibleTag == "!--" {
                        goodTag = true
                    }
                }
            } 
            
            // Check the beginning of the line for significant characters.
            if phase == .leadingPunctuation {
                if openHTMLblock {
                    phase = .text
                    nextLine.makeHTML()
                } else if leadingNumberPeriodAndSpace {
                    if char.isWhitespace {
                        continue
                    } else {
                        phase = .text
                    }
                } else if leadingNumberAndPeriod {
                    if char.isWhitespace {
                        nextLine.makeOrdered(previousLine: lastLine,
                                             previousNonBlankLine: lastNonBlankLine)
                        leadingNumberPeriodAndSpace = true
                        continue
                    } else {
                        phase = .text
                        nextLine.textFound = true
                        startText = startNumber
                    }
                } else if leadingNumber {
                    if char.isNumber {
                        continue
                    } else if char == "." {
                        leadingNumberAndPeriod = true
                        continue
                    } else {
                        phase = .text
                        nextLine.textFound = true
                        startText = startNumber
                    }
                } else if nextLine.leadingBulletAndSpace {
                    if char.isWhitespace {
                        continue
                    } else {
                        phase = .text
                    }
                } else if leadingBullet {
                    if char.isWhitespace {
                        nextLine.leadingBulletAndSpace = true
                        // Let's provisionally identify this as an unordered item,
                        // even though it may turn out later to be h2 underline
                        // or a horizontal rule; at least this will prevent the
                        // line from being declared a follow-on line.
                        nextLine.type = .unorderedItem
                    } else {
                        phase = .text
                        nextLine.textFound = true
                        startText = startBullet
                    }
                } else if nextLine.leadingColonAndSpace {
                    if char.isWhitespace {
                        continue
                    } else {
                        phase = .text
                    }
                } else if leadingColon {
                    if char.isWhitespace {
                        nextLine.leadingColonAndSpace = true
                        nextLine.makeDefItem(requestedType: .defDefinition,
                                             previousLine: lastLine,
                                             previousBlankLIne: lastBlankLine,
                                             previousDefLine: lastDefLine)
                    } else {
                        phase = .text
                        nextLine.textFound = true
                        startText = startColon
                    }
                } else if codeFenced
                            // && char.isWhitespace
                {
                    phase = .text
                    nextLine.textFound = true
                } else if char == " " && spaceCount < 3 {
                    spaceCount += 1
                    continue
                } else {
                    spaceCount = 0
                    if char == "\t" || char == " " {
                        if nextLine.indentLevels == 0 && withinFootnote {
                            nextLine.withinFootnote = true
                        } else if nextLine.indentLevels == 0 && withinCitation {
                            nextLine.withinCitation = true
                        } else {
                            nextLine.indentLevels += 1
                            let continuedBlock = nextLine.continueBlock(previousLine: lastLine,
                                                                    previousNonBlankLine: lastNonBlankLine,
                                                                    forLevel: nextLine.indentLevels)
                            if continuedBlock {
                                continue
                            } else {
                                indentToCode = true
                                startText = nextIndex
                                phase = .text
                                nextLine.textFound = true
                                continue
                            }
                        }
                    } else if char == ">" {
                        nextLine.blocks.append("blockquote")
                        continue
                    } else if char == "#" {
                        _ = nextLine.incrementHashCount()
                        continue
                    } else if char == "-" || char == "+" || char == "*" {
                        leadingBullet = true
                        startBullet = lastIndex
                        continue
                    } else if char == ":" {
                        leadingColon = true
                        startColon = lastIndex
                        continue
                    } else if char.isNumber {
                        if following &&
                            (!followingType.isNumberedItem) {
                            phase = .text
                        } else {
                            leadingNumber = true
                            startNumber = lastIndex
                            continue
                        }
                    } else if char == "[" && nextLine.indentLevels < 1 {
                        linkLabelPhase = .leftBracket
                        refLink = RefLink()
                        footnote = MkdownFootnote()
                        citation = MkdownCitation()
                        phase = .text
                    } else {
                        phase = .text
                    }
                }
            }
            
            // See if we're looking for code
            if indentToCode && nextLine.type == .blank {
                if !char.isWhitespace {
                    nextLine.makeCode()
                } else {
                    continue
                }
            }
            
            // Now look for text
            if phase == .text {
                if nextLine.type == .blank {
                    switch lastLine.type {
                    case .blank:
                        nextLine.makeOrdinary()
                    case .ordinaryText, .followOn, .orderedItem, .unorderedItem, .footnoteItem, .citationItem:
                        nextLine.makeFollowOn(previousLine: lastLine)
                    default:
                        nextLine.makeOrdinary()
                    }
                }
                if !nextLine.textFound {
                     nextLine.textFound = true
                     startText = lastIndex
                }
                if char == " " {
                    nextLine.trailingSpaceCount += 1
                } else {
                    nextLine.trailingSpaceCount = 0
                }
                if char == "\\" {
                    if nextLine.endsWithBackSlash {
                        nextLine.endsWithBackSlash = false
                    } else {
                        nextLine.endsWithBackSlash = true
                    }
                } else {
                    nextLine.endsWithBackSlash = false
                }
                if char == "#" && nextLine.hashCount > 0 && nextLine.hashCount < 7 {
                    // Drop trailing hash marks
                } else {
                    endText = nextIndex
                }
                
                // Let's see if we have a possible reference link definition in work.
                if linkLabelPhase != .na {
                    linkLabelExamineChar(char)
                }
                
                // Reset within footnote flag if we found a line that wasn't indented.
                if withinFootnote {
                    if nextLine.withinFootnote {
                        // OK
                    } else if char == " " && spaceCount > 0 && nextLine.indentLevels == 0 {
                        // OK
                    } else {
                        withinFootnote = false
                    }
                }
                
                // Reset within citation flag if we found a line that wasn't indented.
                if withinCitation {
                    if nextLine.withinCitation {
                        // OK
                    } else if char == " " && spaceCount > 0 && nextLine.indentLevels == 0 {
                        // OK
                    } else {
                        withinCitation = false
                    }
                }
            } // End of looking at text character.
            
            // Now let's look for indications of a math line.
            if options.mathJax {
                if mathLineStart.count < 2 {
                    mathLineStart.append(char)
                    startMath = nextIndex
                } else if mathLineStart.count < 3 && mathLineStart != "$$" {
                    mathLineStart.append(char)
                    startMath = nextIndex
                }
                
                if mathLineValidStart {
                    if char.isWhitespace {
                        mathLineEndTrailingWhiteSpace = true
                    } else {
                        if mathLineEndTrailingWhiteSpace {
                            mathLineEnd = ""
                            mathLineEndTrailingWhiteSpace = false
                            endMath = lastIndex
                        }
                        mathLineEnd.append(char)
                        if mathLineEnd.count > 3 {
                            mathLineEnd.remove(at: mathLineEnd.startIndex)
                            endMath = mkdown.index(after: endMath)
                        }
                        if mathLineEnd.count > 2 && mathLineEnd.hasSuffix("$$") {
                            mathLineEnd.remove(at: mathLineEnd.startIndex)
                            endMath = mkdown.index(after: endMath)
                        }
                    }
                }
            }
            
        } // End of processing each character.
        finishLine()
    } // end of func
    
    /// Prepare for a new Markdown line.
    func beginLine() {
        nextLine = MkdownLine()
        lineIndex = -1
        startText = nextIndex
        startLine = nextIndex
        endLine = nextIndex
        endText = nextIndex
        phase = .leadingPunctuation
        spaceCount = 0
        if linkLabelPhase != .linkEnd {
            linkLabelPhase = .na
            angleBracketsUsed = false
            refLink = RefLink()
        }
        titleEndChar = " "
        leadingNumber = false
        leadingNumberAndPeriod = false
        leadingNumberPeriodAndSpace = false
        leadingBullet = false
        leadingColon = false
        startNumber = nextIndex
        startBullet = nextIndex
        startColon = nextIndex
        leadingLeftAngleBracket = false
        leadingLeftAngleBracketAndSlash = false
        possibleTag = ""
        possibleTagPending = false
        goodTag = false
        indentToCode = false
        following = lastLine.type == .ordinaryText || lastLine.type == .followOn
        if lastLine.type != .followOn {
            followingType = lastLine.type
        }
        mathLineStart = ""
        mathLineEnd = ""
        mathLineEndTrailingWhiteSpace = false
        startMath = nextIndex
        endMath = nextIndex

    }
    
    /// Wrap up initial examination of the line and figure out what to do with it.
    func finishLine() {
        
        counts.lines += 1
        
        // Capture the entire line for later processing.
        if endLine > startLine {
            nextLine.line = String(mkdown[startLine..<endLine])
        }
        
        // Figure out some of the less ordinary line types.
        if nextLine.codeFence(inProgress: codeFenced,
                                     lastChar: codeFenceChar,
                                     lastRepeatCount: codeFenceRepeatCount) {
            nextLine.type = .codeFence
            if codeFenced {
                codeFenced = false
                codeFenceChar = " "
                codeFenceRepeatCount = 0
            } else {
                codeFenced = true
                codeFenceChar = nextLine.repeatingChar
                codeFenceRepeatCount = nextLine.repeatCount
            }
        } else if nextLine.type == .code {
            // Don't bother looking in code for other indicators
        } else if codeFenced {
            nextLine.makeCode()
        } else if (refLink.isValid
            && (linkLabelPhase == .linkEnd || linkLabelPhase == .linkStart)) {
            linkDict[refLink.label] = refLink
            nextLine.type = .linkDef
            linkLabelPhase = .linkEnd
        } else if refLink.isValid && linkLabelPhase == .titleEnd {
            let def = linkDict[refLink.label]
            if def == nil {
                linkDict[refLink.label] = refLink
                nextLine.type = .linkDef
            } else {
                nextLine.type = .linkDefExt
            }
        } else if footnote.isValid && linkLabelPhase == .noteStart {
            footnote.inputLine = nextLine.line
            _ = addFootnote()
            nextLine.type = .footnoteDef
            withinFootnote = true
        } else if citation.isValid && linkLabelPhase == .citationStart {
            citation.inputLine = nextLine.line
            _ = addCitation()
            nextLine.type = .citationDef
            withinCitation = true
        } else if openHTMLblock {
            // Don't bother checking anything else
        } else if nextLine.headingUnderlining && nextLine.horizontalRule {
            if lastLine.type == .blank {
                nextLine.makeHorizontalRule()
            } else if nextLine.repeatCount > 4 {
                nextLine.type = .h2Underlines
            } else {
                nextLine.makeHorizontalRule()
            }
        } else if nextLine.headingUnderlining {
            if nextLine.repeatingChar == "=" {
                nextLine.type = .h1Underlines
            } else {
                nextLine.type = .h2Underlines
            }
        } else if nextLine.horizontalRule {
            nextLine.makeHorizontalRule()
        } else if nextLine.hashCount >= 1 && nextLine.hashCount <= 6 {
            nextLine.makeHeading(level: nextLine.hashCount, headingNumbers: &headingNumbers)
        } else if nextLine.hashCount > 0 {
            startText = startLine
            nextLine.makeOrdinary()
        } else if nextLine.leadingBulletAndSpace {
            if following && followingType != .unorderedItem {
                startText = startLine
                nextLine.leadingBulletAndSpace = false
                nextLine.type = .followOn
            } else {
                nextLine.makeUnordered(previousLine: lastLine,
                                       previousNonBlankLine: lastNonBlankLine)
            }
        } else if options.mathJax && mathLineStart == "$$" && mathLineEnd == "$$" {
            nextLine.makeMath()
            startText = startMath
            endText = endMath
        } else if options.mathJax && mathLineStart == "\\\\[" && mathLineEnd == "\\\\]" {
            nextLine.makeMath()
            startText = startMath
            endText = endMath
        } else {
            let lineLowered = nextLine.line.lowercased()
            if lineLowered.hasPrefix("{:") {
                if lineLowered.hasPrefix("{:collection-toc") {
                    nextLine.type = .tocForCollection
                } else if lineLowered.hasPrefix("{:index") {
                    nextLine.type = .index
                } else if lineLowered.hasPrefix("{:tags-outline") {
                    nextLine.type = .tagsOutline
                } else if lineLowered.hasPrefix("{:toc") {
                    nextLine.type = .tableOfContents
                    tocFound = true
                }
            } else if lineLowered == "[toc]" {
                nextLine.type = .tableOfContents
                tocFound = true
            }
        }
        
        // Check for lines of HTML
        if openHTMLblock {
            if nextLine.type == .blank {
                openHTMLblock = false
            } else {
                nextLine.makeHTML()
                if (leadingLeftAngleBracketAndSlash
                    && goodTag
                    && possibleTag == openHTMLblockTag) {
                    openHTMLblock = false
                }
            }
        } else if (lastLine.type == .blank
            && leadingLeftAngleBracket
            && !leadingLeftAngleBracketAndSlash
            && goodTag) {
            nextLine.makeHTML()
            if possibleTag != "hr" {
                openHTMLblockTag = possibleTag
                openHTMLblock = true
            }
        }
        if nextLine.type == .html {
            startText = startLine
        }
        
        // If the line ends with a backslash, treat this like a line break.
        if nextLine.type != .code && nextLine.endsWithBackSlash {
            endText = mkdown.index(before: endText)
            nextLine.trailingSpaceCount = 2
        }

        // Capture the text portion of the line, if it has any.
        if nextLine.type.hasText && endText > startText {
            nextLine.text = String(mkdown[startText..<endText])
        }
        
        if nextLine.type.textMayContinue && nextLine.trailingSpaceCount == 0 {
            nextLine.text.append(" ")
        }
        
        // If the line has no content and no end of line character(s), then ignore it.
        guard !nextLine.isEmpty else { return }
        
        if nextLine.type == .h1Underlines {
            lastLine.makeHeading(level: 1, headingNumbers: &headingNumbers)
        } else if nextLine.type == .h2Underlines {
            lastLine.makeHeading(level: 2, headingNumbers: &headingNumbers)
        }
        
        if lastLine.quoteLevel > 0 && nextLine.type == .ordinaryText && nextLine.quoteLevel == 0 {
            nextLine.quoteLevel = lastLine.quoteLevel
        }
        
        if nextLine.type == .followOn {
            nextLine.carryBlockquotesForward(lastLine: lastLine)
        }
        
        if nextLine.type == .followOn || nextLine.type == .ordinaryText {
            nextLine.addParagraph()
        }
        
        if nextLine.type == .blank {
            lastLine.trailingSpaceCount = 0
        }
        
        if nextLine.type.isDefItem {
            lastDefLine = nextLine
            nonDefCount = 0
        } else if nextLine.type == .ordinaryText {
            nonDefCount += 1
        } else if nextLine.type != .blank {
            nonDefCount = 3
        }
        if nonDefCount > 1 {
            lastDefLine = MkdownLine()
        }
        
        switch nextLine.type {
        case .h1Underlines, .h2Underlines, .linkDef, .linkDefExt, .footnoteDef, .citationDef:
            break
        case .blank:
            if withinFootnote && (footnote.lines.count == 0 || lastLine.type != .blank) {
                footnote.lines.append(nextLine)
            } else if withinCitation && (citation.lines.count == 0 && lastLine.type != .blank) {
                citation.lines.append(nextLine)
            } else if lastLine.type == .blank {
                break
            } else {
                lines.append(nextLine)
            }
            lastLine = nextLine
            lastBlankLine = nextLine
        default:
            if withinFootnote {
                footnote.lines.append(nextLine)
            } else if withinCitation {
                citation.lines.append(nextLine)
            } else {
                lines.append(nextLine)
            }
            lastLine = nextLine
            lastNonBlankLine = nextLine
        }

    }
    
    /// Figure out what to do with the next character found as part of a link label definition. 
    func linkLabelExamineChar(_ char: Character) {
         
         switch linkLabelPhase {
         case .na:
             break
         case .leftBracket:
             if char == "[" && refLink.label.count == 0 {
                 break
             } else if char == "]" {
                 linkLabelPhase = .rightBracket
             } else if char == "^" && refLink.label.count == 0 && footnote.label.count == 0 {
                linkLabelPhase = .caret
             } else if char == "#" && refLink.label.count == 0 && citation.label.count == 0 {
                linkLabelPhase = .poundSign
             } else {
                 refLink.label.append(char.lowercased())
             }
         case .caret:
            if char == "^" && footnote.label.count == 0 {
                break
            } else if char == "]" {
                linkLabelPhase = .rightBracket
            } else {
                footnote.label.append(char.lowercased())
            }
         case .poundSign:
            if char == "#" && citation.label.count == 0 {
                break
            } else if char == "]" {
                linkLabelPhase = .rightBracket
            } else {
                citation.label.append(char)
            }
         case .rightBracket:
             if char == ":" {
                 linkLabelPhase = .colon
             } else {
                 linkLabelPhase = .na
             }
         case .colon:
             if !char.isWhitespace {
                 if char == "<" {
                     angleBracketsUsed = true
                     linkLabelPhase = .linkStart
                 } else if footnote.label.count > 0 {
                    footnote.text.append(char)
                    linkLabelPhase = .noteStart
                 } else if citation.label.count > 0 {
                    citation.text.append(char)
                    linkLabelPhase = .citationStart
                 } else {
                     refLink.link.append(char)
                     linkLabelPhase = .linkStart
                 }
             }
         case .noteStart:
            footnote.text.append(char)
         case .citationStart:
            citation.text.append(char)
         case .linkStart:
             if angleBracketsUsed {
                 if char == ">" {
                     linkLabelPhase = .linkEnd
                 } else {
                     refLink.link.append(char)
                 }
             } else if char.isWhitespace {
                 linkLabelPhase = .linkEnd
             } else {
                 refLink.link.append(char)
             }
         case .linkEnd:
             if char == "\"" || char == "'" || char == "(" {
                 linkLabelPhase = .titleStart
                 if char == "(" {
                     titleEndChar = ")"
                 } else {
                     titleEndChar = char
                 }
             } else if !char.isWhitespace {
                 linkLabelPhase = .na
             }
         case .titleStart:
             if char == titleEndChar {
                 linkLabelPhase = .titleEnd
             } else {
                 refLink.title.append(char)
             }
         case .titleEnd:
             if !char.isWhitespace {
                 linkLabelPhase = .na
             }
         }
     }
    
    // ===========================================================
    //
    // This is the data shared between Phase 1 and Phase 2.
    //
    // ===========================================================
    
    var linkDict: [String:RefLink] = [:]
    var footnotes: [MkdownFootnote] = []
    var citations: [MkdownCitation] = []
    var lines:    [MkdownLine] = []
    var tocFound = false

    // ===========================================================
    //
    // Phase 2 - Take the lines and convert them to HTML output.
    //
    // ===========================================================
    
    var mainLineIndex = 0
    
    var tocLines: [MkdownLine] = []
    var tocLineIndex = 0
    
    var footnoteLines: [MkdownLine] = []
    var footnoteLinesGenerated = false
    var footnoteLineIndex = 0
    
    var citationLines: [MkdownLine] = []
    var citationLinesGenerated = false
    var citationLineIndex = 0
    
    var mainlineComplete = false
    
    var writer = Markedup()
    
    public var html: String { return writer.code }
    
    var lastQuoteLevel = 0
    var openBlock = ""
    
    var nextChunk = MkdownChunk()
    var chunks: [MkdownChunk] = []
    
    var startChunk = MkdownChunk()
    var consecutiveStartCount = 0
    var consecutiveCloseCount = 0
    var leftToClose = 0
    var start = -1
    var matchStart = -1
    
    var anotherWord = false
    
    var backslashed = false
    
    var openBlocks = MkdownBlockStack()
    
    /// Now that we have the input divided into lines, and the lines assigned types,
    /// let's generate the output HTML.
    func linesOut() {
        
        if tocFound {
            genTableOfContents()
        }
        
        writeHTML()
    }
    
    /// Generate a table of contents when requested.
    func genTableOfContents() {
        tocFound = false
        tocLines = []
        var firstHeadingLevel = 0
        var lastHeadingLevel = 0
        var indentLevels = 0
        var lastLine = MkdownLine()
        for line in lines {
            if line.type == .tableOfContents {
                tocFound = true
                continue
            }
            if !tocFound {
                continue
            }
            if line.type != .heading {
                continue
            }
            
            if firstHeadingLevel == 0 {
                firstHeadingLevel = line.headingLevel
                lastHeadingLevel = line.headingLevel
            }
            
            let tocLine = MkdownLine()
            
            let headingText = line.text
            let headingID = StringUtils.toCommonFileName(headingText)
            tocLine.text = "[\(headingText)](#\(headingID))"
            
            if line.headingLevel > lastHeadingLevel {
                indentLevels += 1
                lastHeadingLevel = line.headingLevel
            } else if line.headingLevel < lastHeadingLevel {
                if indentLevels > 0 {
                    indentLevels -= 1
                }
                lastHeadingLevel = line.headingLevel
            }
            tocLine.indentLevels = indentLevels
            
            tocLine.makeUnordered(previousLine: lastLine, previousNonBlankLine: lastLine)
            
            tocLines.append(tocLine)
            lastLine = tocLine
        }
    }
    
    /// Go through the Markdown lines, writing out HTML.
    func writeHTML() {
        writer = Markedup()
        lastQuoteLevel = 0
        openBlocks = MkdownBlockStack()
        
        mainLineIndex = 0
        tocLineIndex = 0
        
        var possibleLine = getNextLine()
        
        while possibleLine != nil {
            
            let line = possibleLine!
            
            // line.display()
            
            if !line.followOn {
                // Close any outstanding blocks that are no longer in effect.
                var startToClose = 0
                while startToClose < openBlocks.count {
                    guard startToClose < line.blocks.count else { break }
                    if openBlocks.blocks[startToClose] != line.blocks.blocks[startToClose] {
                        break
                    }
                    startToClose += 1
                }
                
                closeBlocks(from: startToClose)
                
                // Now start any new business.
                
                var blockToOpenIndex = openBlocks.count
                var listItemIndex = 0
                while blockToOpenIndex < line.blocks.count {
                    let blockToOpen = line.blocks.blocks[blockToOpenIndex]
                    if blockToOpen.isListItem {
                        listItemIndex = openBlocks.count
                    } else if blockToOpen.isParagraph {
                        listItemIndex = 0
                    }
                    openBlock(blockToOpen.tag,
                              footnoteItem: blockToOpen.footnoteItem,
                              citationItem: blockToOpen.citationItem,
                              itemNumber: blockToOpen.itemNumber,
                              text: line.text)
                    openBlocks.append(blockToOpen)
                    blockToOpenIndex += 1
                }
                
                if listItemIndex > 0 {
                    let listIndex = listItemIndex - 1
                    let listBlock = openBlocks.blocks[listIndex]
                    if listBlock.isListTag && listBlock.listWithParagraphs {
                        let paraBlock = MkdownBlock("p")
                        openBlock(paraBlock.tag, footnoteItem: false, citationItem: false, itemNumber: 0, text: "")
                        openBlocks.append(paraBlock)
                    }
                }
            }
            
            switch line.type {
            case .code:
                chunkAndWrite(line)
                writer.newLine()
            case .heading:
                if line.headingNumber > 0 {
                    let headingNumberChunk = MkdownChunk(line: line)
                    headingNumberChunk.text = "\(line.headingNumber). "
                    addChunk(headingNumberChunk)
                }
                chunkAndWrite(line)
            case .horizontalRule:
                writer.horizontalRule()
            case .html:
                writer.writeLine(line.line)
            case .ordinaryText:
                textToChunks(line)
            case .orderedItem, .unorderedItem, .footnoteItem, .citationItem:
                textToChunks(line)
            case .defTerm, .defDefinition:
                textToChunks(line)
            case .followOn:
                textToChunks(line)
            case .index:
                if mkdownContext != nil {
                    writer.writeLine(mkdownContext!.mkdownIndex())
                }
            case .tagsOutline:
                if mkdownContext != nil {
                    writer.writeLine(mkdownContext!.mkdownTagsOutline())
                }
            case .tocForCollection:
                if mkdownContext != nil {
                    writer.writeLine(mkdownContext!.mkdownCollectionTOC(commandText: line.text))
                }
            case .math:
                writer.writeLine("$$\(line.text)$$")
            case .blank:
                break
            case .citationDef:
                break
            case .codeFence:
                break
            case .h1Underlines:
                break
            case .h2Underlines:
                break
            case .linkDef:
                break
            case .linkDefExt:
                break
            case .footnoteDef:
                break
            case .tableOfContents:
                break
            }
            
            if line.endOfFootnote {
                outputChunks()
                let listItem = line.blocks.getListItem(atLevel: 0)
                writeFootnoteReturn(number: listItem.itemNumber)
            } else if line.endOfCitation {
                outputChunks()
                let listItem = line.blocks.getListItem(atLevel: 0)
                if listItem.notCited {
                    // skip the return
                } else {
                    writeCitationReturn(number: listItem.itemNumber)
                }
            }
            
            possibleLine = getNextLine()
            
        }
        closeBlocks(from: 0)
        
        if footnoteLines.count > 0 {
            finishWritingFootnotes()
        }
        if citationLines.count > 0 {
            finishWritingCitations()
        }
    }
    
    /// Get the next markdown line to be processed, pulling from the table of contents array
    /// and the footnote list when appropriate.
    func getNextLine() -> MkdownLine? {
        
        if mainLineIndex >= lines.count {
            if !mainlineComplete {
                closeBlocks(from: 0)
                mainlineComplete = true
            }
            if footnotes.count > 0 && !footnoteLinesGenerated {
                startWritingFootnotes()
                genFootnotes()
                footnoteLineIndex = 0
                footnoteLinesGenerated = true
            }
            if footnoteLineIndex < footnoteLines.count {
                nextLine = footnoteLines[footnoteLineIndex]
                footnoteLineIndex += 1
                return nextLine
            }
            if citations.count > 0 && !citationLinesGenerated {
                closeBlocks(from: 0)
                startWritingCitations()
                genCitations()
                citationLineIndex = 0
                citationLinesGenerated = true
            }
            if citationLineIndex < citationLines.count {
                nextLine = citationLines[citationLineIndex]
                citationLineIndex += 1
                return nextLine
            }
            return nil
        }

        var nextLine = lines[mainLineIndex]
        if nextLine.type == .tableOfContents {
            if tocLineIndex < tocLines.count {
                // Pull the next line from the ToC array
                nextLine = tocLines[tocLineIndex]
                tocLineIndex += 1
                return nextLine
            } else {
                // Done with ToC array
                mainLineIndex += 1
                guard mainLineIndex < lines.count else { return nil }
                nextLine = lines[mainLineIndex]
            }
        }
        mainLineIndex += 1
        return nextLine
    }
    
    /// Write out HTML to start footnote section of the document.
    func startWritingFootnotes() {
        writer.startDiv(klass: "footnotes")
        writer.horizontalRule()
    }
    
    /// Write out HTML to end the footnote section of the document.
    func finishWritingFootnotes() {
        writer.finishDiv()
    }
    
    /// Write out HTML to start citations section of the document.
    func startWritingCitations() {
        writer.startDiv(klass: "citations")
        writer.horizontalRule()
    }
    
    /// Write out HTML to end the citations section of the document.
    func finishWritingCitations() {
        writer.finishDiv()
    }
    
    /// Generate HTML to return from the footnote to the referencing text.
    func writeFootnoteReturn(number: Int) {
        writer.append(" ")
        writer.openTag("a")
        writer.addHref("#fnref:\(number)")
        writer.addTitle("return to article")
        writer.addClass("reversefootnote")
        writer.closeTag()
        writer.appendNumberedAttribute(number: 160)
        writer.appendNumberedAttribute(number: 8617)
        writer.finishLink()
    }
    
    /// Generate HTML to return from the citation to the referencing text.
    func writeCitationReturn(number: Int) {
        writer.append(" ")
        writer.openTag("a")
        writer.addHref("#cnref:\(number)")
        writer.addTitle("return to body")
        writer.addClass("reversecitation")
        writer.closeTag()
        writer.appendNumberedAttribute(number: 160)
        writer.appendNumberedAttribute(number: 8617)
        writer.finishLink()
    }
    
    /// Generate footnotes.
    func genFootnotes() {
        
        lastQuoteLevel = 0
        openBlocks = MkdownBlockStack()
        
        footnoteLines = []

        footnotes.sort()
        lastLine = MkdownLine()
        lastNonBlankLine = MkdownLine()
        var footnoteIndex = 0
        while footnoteIndex < footnotes.count {
            let nextFootnote = footnotes[footnoteIndex]
            nextFootnote.pruneTrailingBlankLines()
            let footnoteLine = MkdownLine()
            footnoteLine.makeFootnoteItem(previousLine: lastLine, previousNonBlankLine: lastNonBlankLine)
            if nextFootnote.text.count > 0 {
                footnoteLine.text = nextFootnote.text
            } else {
                footnoteLine.text = nextFootnote.label
            }
            footnoteLine.line = nextFootnote.inputLine
            if nextFootnote.lines.isEmpty {
                footnoteLine.endOfFootnote = true
            }
            addFootnoteLine(footnoteLine)
            var lineCount = 0
            for line in nextFootnote.lines {
                lineCount += 1
                _ = line.continueFootnoteOrCitation(line: footnoteLine)
                if lineCount >= nextFootnote.lines.count {
                    line.endOfFootnote = true
                }
                addFootnoteLine(line)
            }
            footnoteIndex += 1
        }
    }
    
    /// Add the next footnote line.
    func addFootnoteLine(_ nextLine: MkdownLine) {
        switch nextLine.type {
        case .blank:
            if lastLine.type == .blank {
                break
            } else {
                footnoteLines.append(nextLine)
            }
            lastLine = nextLine
        default:
            footnoteLines.append(nextLine)
            lastLine = nextLine
            lastNonBlankLine = nextLine
        }
    }
    
    /// Generate citations.
    func genCitations() {
        
        lastQuoteLevel = 0
        openBlocks = MkdownBlockStack()
        
        citationLines = []

        citations.sort()
        lastLine = MkdownLine()
        lastNonBlankLine = MkdownLine()
        var citationIndex = 0
        while citationIndex < citations.count {
            let nextCitation = citations[citationIndex]
            nextCitation.pruneTrailingBlankLines()
            let citationLine = MkdownLine()
            citationLine.makeCitationItem(cited: nextCitation.cited, previousLine: lastLine, previousNonBlankLine: lastNonBlankLine)
            if nextCitation.text.count > 0 {
                citationLine.text = nextCitation.text
            } else {
                citationLine.text = nextCitation.label
            }
            citationLine.line = nextCitation.inputLine
            if nextCitation.lines.isEmpty {
                citationLine.endOfCitation = true
            }
            addCitationLine(citationLine)
            var lineCount = 0
            for line in nextCitation.lines {
                lineCount += 1
                _ = line.continueFootnoteOrCitation(line: citationLine)
                if lineCount >= nextCitation.lines.count {
                    line.endOfCitation = true
                }
                addCitationLine(line)
            }
            citationIndex += 1
        }
    }
    
    /// Add the next citation line.
    func addCitationLine(_ nextLine: MkdownLine) {
        switch nextLine.type {
        case .blank:
            if lastLine.type == .blank {
                break
            } else {
                citationLines.append(nextLine)
            }
            lastLine = nextLine
        default:
            citationLines.append(nextLine)
            lastLine = nextLine
            lastNonBlankLine = nextLine
        }
    }
    
    /// Start writing an HTML block.
    func openBlock(_ tag: String, footnoteItem: Bool, citationItem: Bool, itemNumber: Int, text: String) {
        outputUnwrittenChunks()
        switch tag {
        case "blockquote":
            writer.startBlockQuote()
        case "code":
            writer.startCode()
        case "dd":
            writer.startDefDef()
        case "dl":
            writer.startDefinitionList(klass: nil)
        case "dt":
            writer.startDefTerm()
        case "h1":
            writer.startHeading(level: 1, id: StringUtils.toCommonFileName(text))
        case "h2":
            writer.startHeading(level: 2, id: StringUtils.toCommonFileName(text))
        case "h3":
            writer.startHeading(level: 3, id: StringUtils.toCommonFileName(text))
        case "h4":
            writer.startHeading(level: 4, id: StringUtils.toCommonFileName(text))
        case "h5":
            writer.startHeading(level: 5, id: StringUtils.toCommonFileName(text))
        case "h6":
            writer.startHeading(level: 6, id: StringUtils.toCommonFileName(text))
        case "li":
            if footnoteItem {
                writer.openTag("li")
                writer.addID("fn:\(itemNumber)")
                writer.closeTag()
            } else if citationItem {
                writer.openTag("li")
                writer.addID("cn:\(itemNumber)")
                writer.closeTag()
            } else {
                writer.startListItem()
            }
        case "ol":
            writer.startOrderedList(klass: nil)
        case "p":
            writer.startParagraph()
        case "pre":
            writer.startPreformatted()
        case "ul":
            writer.startUnorderedList(klass: nil)
        default:
            print("Don't know how to open tag of \(tag)")
        }
        chunks = []
    }
    
    func closeBlocks(from startToClose: Int) {
        var blockToClose = openBlocks.count - 1
        while blockToClose >= startToClose {
            let block = openBlocks.blocks[blockToClose]
            closeBlock(tag: block.tag, footnoteItem: block.footnoteItem, citationItem: block.citationItem, itemNumber: block.itemNumber)
            openBlocks.removeLast()
            blockToClose -= 1
        }
    }
    
    func closeBlock(tag: String, footnoteItem: Bool, citationItem: Bool, itemNumber: Int) {
        outputChunks()
        switch tag {
        case "blockquote":
            writer.finishBlockQuote()
        case "code":
            writer.finishCode()
        case "dd":
            writer.finishDefDef()
        case "dl":
            writer.finishDefinitionList()
        case "dt":
            writer.finishDefTerm()
        case "h1":
            writer.finishHeading(level: 1)
        case "h2":
            writer.finishHeading(level: 2)
        case "h3":
            writer.finishHeading(level: 3)
        case "h4":
            writer.finishHeading(level: 4)
        case "h5":
            writer.finishHeading(level: 5)
        case "h6":
            writer.finishHeading(level: 6)
        case "li":
            writer.finishListItem()
        case "ol":
            writer.finishOrderedList()
        case "p":
            writer.finishParagraph()
        case "pre":
            writer.finishPreformatted()
        case "ul":
            writer.finishUnorderedList()
        default:
            print("Don't know how to close tag of \(tag)")
        }
    }
    
    /// Divide a line up into chunks, then write them out.
    func chunkAndWrite(_ line: MkdownLine) {
        textToChunks(line)
        outputChunks()
    }
    
    // ===========================================================
    //
    // Section 2.a - Go through the text in a block and break it
    // up into chunks.
    //
    // ===========================================================
    
    /// Divide another line of Markdown into chunks.
    func textToChunks(_ line: MkdownLine) {
        
        nextChunk = MkdownChunk(line: line)
        backslashed = false
        var lastChar: Character = " "
        if line.type == .followOn {
            nextChunk.startsWithSpace = true
            nextChunk.endsWithSpace = true
            appendToNextChunk(str: " ", lastChar: " ", line: line)
        }
        for char in line.text {
            if line.type == .code {
                switch char {
                case "<":
                    addCharAsChunk(char: char, type: .leftAngleBracket, lastChar: lastChar, line: line)
                case ">":
                    addCharAsChunk(char: char, type: .rightAngleBracket, lastChar: lastChar, line: line)
                case "&":
                    addCharAsChunk(char: char, type: .ampersand, lastChar: lastChar, line: line)
                default:
                    appendToNextChunk(char: char, lastChar: lastChar, line: line)
                }
            } else if backslashed {
                addCharAsChunk(char: char, type: .literal, lastChar: lastChar, line: line)
                backslashed = false
            } else {
                switch char {
                case "\\":
                    addCharAsChunk(char: char, type: .backSlash, lastChar: lastChar, line: line)
                    backslashed = true
                case "*":
                    addCharAsChunk(char: char, type: .asterisk, lastChar: lastChar, line: line)
                case "_":
                    addCharAsChunk(char: char, type: .underline, lastChar: lastChar, line: line)
                case "<":
                    addCharAsChunk(char: char, type: .leftAngleBracket, lastChar: lastChar, line: line)
                case ">":
                    addCharAsChunk(char: char, type: .rightAngleBracket, lastChar: lastChar, line: line)
                case "@":
                    addCharAsChunk(char: char, type: .atSign, lastChar: lastChar, line: line)
                case ":":
                    addCharAsChunk(char: char, type: .colon, lastChar: lastChar, line: line)
                case "[":
                    addCharAsChunk(char: char, type: .leftSquareBracket, lastChar: lastChar, line: line)
                case "^":
                    addCharAsChunk(char: char, type: .caret, lastChar: lastChar, line: line)
                case "#":
                    addCharAsChunk(char: char, type: .poundSign, lastChar: lastChar, line: line)
                case "]":
                    addCharAsChunk(char: char, type: .rightSquareBracket, lastChar: lastChar, line: line)
                case "(":
                    addCharAsChunk(char: char, type: .leftParen, lastChar: lastChar, line: line)
                case ")":
                    addCharAsChunk(char: char, type: .rightParen, lastChar: lastChar, line: line)
                case "$":
                    addCharAsChunk(char: char, type: .dollarSign, lastChar: lastChar, line: line)
                case "\"":
                    addCharAsChunk(char: char, type: .doubleQuote, lastChar: lastChar, line: line)
                case "'":
                    addCharAsChunk(char: char, type: .singleQuote, lastChar: lastChar, line: line)
                case "`":
                    addCharAsChunk(char: char, type: .backtickQuote, lastChar: lastChar, line: line)
                case "&":
                    addCharAsChunk(char: char, type: .ampersand, lastChar: lastChar, line: line)
                case "!":
                    addCharAsChunk(char: char, type: .exclamationMark, lastChar: lastChar, line: line)
                case "-", ".":
                    bufferRepeatingCharacters(char: char, lastChar: lastChar, line: line)
                case " ":
                    if nextChunk.text.count == 0 {
                        nextChunk.startsWithSpace = true
                    } else {
                        if anotherWord {
                            nextChunk.wordCount += 1
                            anotherWord = false
                        }
                    }
                    nextChunk.endsWithSpace = true
                    appendToNextChunk(char: char, lastChar: lastChar, line: line)
                default:
                    appendToNextChunk(char: char, lastChar: lastChar, line: line)
                    nextChunk.textCount += 1
                    anotherWord = true
                }
            }
            if !char.isWhitespace {
                nextChunk.endsWithSpace = false
            }
            lastChar = char
        }
        writeCharsFromBuffer(lastChar: lastChar, line: line)
        finishNextChunk(line: line)
        
        if line.endsWithLineBreak {
            outputChunks()
            writer.lineBreak()
        }
    }
    
    func appendToNextChunk(str: String, lastChar: Character, line: MkdownLine) {
        writeCharsFromBuffer(lastChar: lastChar, line: line)
        nextChunk.text.append(str)
    }
    
    func appendToNextChunk(char: Character, lastChar: Character, line: MkdownLine) {
        writeCharsFromBuffer(lastChar: lastChar, line: line)
        nextChunk.text.append(char)
    }
    
    var charBuffer: [Character] = []
    
    func bufferRepeatingCharacters(char: Character,
                                   lastChar: Character,
                                   line: MkdownLine) {
        if charBuffer.count > 0 && charBuffer.count < 3 && char == charBuffer[0] {
            charBuffer.append(char)
            if charBuffer.count == 3 {
                writeCharsFromBuffer(lastChar: lastChar, line: line)
            }
        } else if charBuffer.count > 0 {
            writeCharsFromBuffer(lastChar: lastChar, line: line)
        } else {
            charBuffer.append(char)
        }
    }
    
    func writeCharsFromBuffer(lastChar: Character, line: MkdownLine) {
        
        guard charBuffer.count > 0 else { return }
        
        if charBuffer[0] == "-" {
            if charBuffer.count == 3 {
                charBuffer = []
                addCharAsChunk(char: "-", type: .emdash, lastChar: lastChar, line: line)
            } else if charBuffer.count == 2 {
                charBuffer = []
                addCharAsChunk(char: "-", type: .endash, lastChar: lastChar, line: line)
            } else {
                nextChunk.text.append(charBuffer[0])
            }
        } else if charBuffer[0] == "." {
            if charBuffer.count == 3 {
                charBuffer = []
                addCharAsChunk(char: ".", type: .ellipsis, lastChar: lastChar, line: line)
            } else if charBuffer.count == 2 {
                nextChunk.text.append("..")
            } else {
                nextChunk.text.append(".")
            }
        }
        
        charBuffer = []
    }
    
    /// Add a character as its own chunk.
    func addCharAsChunk(char: Character,
                        type: MkdownChunkType,
                        lastChar: Character,
                        line: MkdownLine) {
        if charBuffer.count > 0 {
            writeCharsFromBuffer(lastChar: lastChar, line: line)
        }
        if nextChunk.text.count > 0 {
            finishNextChunk(line: line)
        }
        nextChunk.setTextFrom(char: char)
        nextChunk.type = type
        nextChunk.spaceBefore = lastChar.isWhitespace
        addChunk(nextChunk)
        nextChunk = MkdownChunk(line: line)
    }
    
    /// Add the chunk to the array.
    func finishNextChunk(line: MkdownLine) {
        if nextChunk.text.count > 0 {
            if nextChunk.type == .plaintext {
                if anotherWord {
                    nextChunk.wordCount += 1
                }
                counts.words += nextChunk.wordCount
                counts.text += nextChunk.textCount
            }
            addChunk(nextChunk)
        }
        nextChunk = MkdownChunk(line: line)
    }
    
    func addChunk(_ chunk: MkdownChunk) {
        if chunks.count > 0 {
            let last = chunks.count - 1
            chunks[last].spaceAfter = chunk.startsWithSpace
        }
        chunks.append(chunk)
    }
    
    func outputUnwrittenChunks() {
        if chunks.count > 0 {
            outputChunks()
        }
    }
    
    /// Now finish evaluation of the chunks and write them out.
    func outputChunks() {
        
        identifyPatterns()
        writeChunks(chunksToWrite: chunks)
        chunks = []
    }
    
    // ===========================================================
    //
    // Section 2.b - Go through the chunks trying to identify
    //               significant patterns.
    //
    // ===========================================================
    
    var withinCodeSpan = false
    var withinMathSpan = false
    var withinTag = false
    
    /// Scan through our accumulated chunks, looking for meaningful patterns of puncutation.
    func identifyPatterns() {
        
        withinCodeSpan = false
        withinMathSpan = false
        var index = 0
        while index < chunks.count {
            let chunk = chunks[index]
            let nextIndex = index + 1
            switch chunk.type {
            case .asterisk, .underline:
                if chunk.lineType == .code { break }
                if withinCodeSpan { break }
                if withinMathSpan { break }
                if withinTag { break }
                scanForEmphasisClosure(forChunkAt: index)
            case .leftAngleBracket:
                if chunk.lineType == .code { break }
                if withinCodeSpan { break }
                if withinMathSpan { break }
                if nextIndex >= chunks.count { break }
                if chunks[nextIndex].startsWithSpace { break }
                let auto = scanForAutoLink(forChunkAt: index)
                if !auto {
                    let inline = scanForInlineTag(forChunkAt: index)
                    if inline {
                        withinTag = true
                    }
                }
            case .ampersand:
                if chunk.lineType == .code { break }
                if withinCodeSpan { break }
                if withinMathSpan { break }
                if withinTag { break }
                if nextIndex >= chunks.count { break }
                if chunks[nextIndex].startsWithSpace { break }
                chunk.type = .entityStart
            case .leftSquareBracket:
                if chunk.lineType == .code { break }
                if withinCodeSpan { break }
                if withinMathSpan { break }
                if withinTag { break }
                scanForLinkElements(forChunkAt: index)
            case .backtickQuote:
                scanForCodeClosure(forChunkAt: index)
                if chunk.type == .startCode {
                    withinCodeSpan = true
                }
            case .singleQuote, .doubleQuote:
                if withinCodeSpan { break }
                if withinTag { break }
                scanForQuotes(forChunkAt: index)
            case .dollarSign:
                if !options.mathJax { break }
                if chunk.lineType == .code { break }
                if withinCodeSpan { break }
                if withinTag { break }
                if nextIndex >= chunks.count { break }
                if chunks[nextIndex].startsWithSpace { break }
                if index > 0 && !chunks[index - 1].endsWithSpace { break }
                scanForDollarSigns(forChunkAt: index)
                if chunk.type == .startMath {
                    withinMathSpan = true
                }
            case .backSlash:
                if !options.mathJax { break }
                if chunk.lineType == .code { break }
                if withinCodeSpan { break }
                if withinTag { break }
                scanForSlashParens(forChunkAt: index)
                if chunk.type == .startMath {
                    withinMathSpan = true
                }
            case .startMath:
                withinMathSpan = true
            case .endMath:
                withinMathSpan = false
            case .startCode:
                withinCodeSpan = true
            case .endCode:
                withinCodeSpan = false
            case .tagStart:
                withinTag = true
            case .tagEnd:
                withinTag = false
            default:
                break
            }
            index += 1
        }
    }
    
    func scanForDollarSigns(forChunkAt: Int) {
        let firstChunk = chunks[forChunkAt]
        guard forChunkAt + 2 < chunks.count else { return }
        var next = forChunkAt + 1
        var nextChunk = chunks[next]
        var matched = false
        while !matched && next < chunks.count {
            nextChunk = chunks[next]
            if nextChunk.type == .dollarSign {
                let nextAfter = next + 1
                if nextAfter >= chunks.count {
                    matched = true
                } else {
                    let followingChunk = chunks[nextAfter]
                    if followingChunk.startsWithSpace || followingChunk.type != .plaintext {
                        matched = true
                    }
                }
            }
            if !matched {
                next += 1
            }
        }
        
        guard matched else { return }
        
        firstChunk.type = .startMath
        nextChunk.type  = .endMath
    }
    
    func scanForSlashParens(forChunkAt: Int) {
        let firstChunk = chunks[forChunkAt]
        
        var next = forChunkAt + 1
        guard next < chunks.count else { return }
        let chunk2 = chunks[next]
        guard chunk2.type == .backSlash ||
                (chunk2.type == .literal && chunk2.text == "\\") else {
            return
        }
        
        next += 1
        guard next < chunks.count else { return }
        let chunk3 = chunks[next]
        guard chunk3.type == .leftParen else { return }
        
        next += 1
        guard next < chunks.count else { return }
        let chunk4 = chunks[next]
        guard !chunk4.startsWithSpace else { return }
        
        var matched = false
        var nextChunk = MkdownChunk()
        var plusOne = MkdownChunk()
        var plusTwo = MkdownChunk()
        while !matched && next < chunks.count {
            next += 1
            guard next < chunks.count else { break }
            nextChunk = chunks[next]
            if nextChunk.type == .backSlash {
                
                guard next + 1 < chunks.count else { return }
                plusOne = chunks[next + 1]
                guard plusOne.type == .backSlash ||
                        (plusOne.type == .literal && plusOne.text == "\\") else {
                    continue
                }
                
                guard next + 2 < chunks.count else { return }
                plusTwo = chunks[next + 2]
                guard plusTwo.type == .rightParen else { continue }
                
                if next + 3 >= chunks.count {
                    matched = true
                    continue
                }
                let plusThree = chunks[next + 3]
                if plusThree.startsWithSpace {
                    matched = true
                    continue
                }
                if plusThree.type != .plaintext {
                    matched = true
                    continue
                }
            }
        }
        
        guard matched else { return }
        
        firstChunk.type = .startMath
        chunk2.type = .skipMath
        chunk3.type = .skipMath
        nextChunk.type = .skipMath
        plusOne.type = .skipMath
        plusTwo.type = .endMath
    }
    
    /// Scan for quotations marks.
    func scanForQuotes(forChunkAt: Int) {
        
        let firstChunk = chunks[forChunkAt]
        if forChunkAt > 0 {
            let priorChunk = chunks[forChunkAt - 1]
            if priorChunk.type == .plaintext {
                let priorChar = priorChunk.text.last
                if priorChar != nil && priorChar!.isLetter {
                    firstChunk.type = .apostrophe
                    return
                }
            }
        }
        
        guard forChunkAt + 2 < chunks.count else { return }
        
        var next = forChunkAt + 1
        var matched = false
        while !matched && next < chunks.count {
            let nextChunk = chunks[next]
            var possibleEndingQuote = true
            if firstChunk.type == .singleQuote {
                let nextAfter = next + 1
                if nextAfter < chunks.count {
                    let followingChunk = chunks[nextAfter]
                    if followingChunk.type == .plaintext {
                        let followingChar = followingChunk.text.first
                        if followingChar != nil {
                            if followingChar!.isLetter || followingChar!.isNumber {
                                possibleEndingQuote = false
                            }
                        }
                    }
                }
            }
            if possibleEndingQuote &&
                nextChunk.type == firstChunk.type
                && next > forChunkAt + 1 {
                matched = true
                if firstChunk.type == .doubleQuote {
                    firstChunk.type = .doubleCurlyQuoteOpen
                    nextChunk.type = .doubleCurlyQuoteClose
                } else if firstChunk.type == .singleQuote {
                    firstChunk.type = .singleCurlyQuoteOpen
                    nextChunk.type = .singleCurlyQuoteClose
                }
            }
            next += 1
        }
    }
    
    func scanForAutoLink(forChunkAt: Int) -> Bool {
        var next = forChunkAt + 1
        var atSignFound = false
        var colonChunkIndex = -1
        var colonAndSlashesFound = false
        while next < chunks.count {
            let nextChunk = chunks[next]
            switch nextChunk.type {
            case .atSign:
                atSignFound = true
            case .colon:
                colonChunkIndex = next
            case .rightAngleBracket:
                if atSignFound || colonAndSlashesFound {
                    chunks[forChunkAt].type = .autoLinkStart
                    nextChunk.type = .autoLinkEnd
                    return true
                } else {
                    return false
                }
            case .plaintext:
                if nextChunk.text.contains(" ") { return false }
                if colonChunkIndex >= 0 && next == colonChunkIndex + 1 && nextChunk.text.starts(with: "//") {
                    colonAndSlashesFound = true
                }
            default:
                break
            }
            next += 1
        }
        
        return false
    }
    
    func scanForInlineTag(forChunkAt: Int) -> Bool {
        let startChunk = chunks[forChunkAt]
        var next = forChunkAt + 1
        while next < chunks.count {
            let nextChunk = chunks[next]
            if nextChunk.type == .leftAngleBracket {
                return false
            } else if nextChunk.type == .rightAngleBracket {
                startChunk.type = .tagStart
                nextChunk.type = .tagEnd
                return true
            } else {
                next += 1
            }
        }
        return false
    }
    
    /// If we have an asterisk or an underline, look for the closing symbols to end the emphasis span.
    func scanForEmphasisClosure(forChunkAt: Int) {
        start = forChunkAt
        startChunk = chunks[start]
        var next = start + 1
        consecutiveStartCount = 1
        leftToClose = 1
        consecutiveCloseCount = 0
        matchStart = -1
        while leftToClose > 0 && next < chunks.count {
            let nextChunk = chunks[next]
            if nextChunk.type == startChunk.type && next == (start + consecutiveStartCount) {
                consecutiveStartCount += 1
                leftToClose += 1
            } else if nextChunk.type == startChunk.type {
                if consecutiveCloseCount == 0 {
                    matchStart = next
                    consecutiveCloseCount = 1
                } else if next == (matchStart + consecutiveCloseCount) {
                    consecutiveCloseCount += 1
                }
            } else if consecutiveCloseCount > 0 {
                processEmphasisClosure()
            }
            next += 1
        }
        processEmphasisClosure()
    }
    
    /// Let's close things up.
    func processEmphasisClosure() {
        guard consecutiveCloseCount > 0 else { return }
        if consecutiveStartCount == consecutiveCloseCount {
            switch consecutiveStartCount {
            case 1:
                startChunk.type = .startEmphasis
                chunks[matchStart].type = .endEmphasis
                consecutiveCloseCount = 0
            case 2:
                startChunk.type = .startStrong1
                chunks[start + 1].type = .startStrong2
                chunks[matchStart].type = .endStrong1
                chunks[matchStart + 1].type = .endStrong2
                consecutiveCloseCount = 0
            case 3:
                startChunk.type = .startStrong1
                chunks[start + 1].type = .startStrong2
                chunks[start + 2].type = .startEmphasis
                chunks[matchStart].type = .endEmphasis
                chunks[matchStart + 1].type = .endStrong1
                chunks[matchStart + 2].type = .endStrong2
                consecutiveCloseCount = 0
            default:
                break
            }
            leftToClose = 0
        } else if consecutiveStartCount == 3 {
            if consecutiveCloseCount == 1 {
                chunks[start + 2].type = .startEmphasis
                chunks[matchStart].type = .endEmphasis
                leftToClose = 2
                consecutiveStartCount = 2
                consecutiveCloseCount = 0
            } else if consecutiveCloseCount == 2 {
                chunks[start + 1].type = .startStrong1
                chunks[start + 2].type = .startStrong2
                chunks[matchStart].type = .endStrong1
                chunks[matchStart + 1].type = .endStrong2
                leftToClose = 1
                consecutiveStartCount = 1
                consecutiveCloseCount = 0
            }
        }
    }
    
    var possibleClosingTick = -1
    var literalBackTicks: [Int] = []
    
    var tickBeforeSpace = -1
    var spaceAfterTick = -1
    var closingTick1 = -1
    var closingTick2 = -1
    
    /// If we have a backtick quote, look for the closing symbols to end the code span.
    func scanForCodeClosure(forChunkAt: Int) {
        
        var doubleTicks = false
        var doubleTicksPlusSpace = false
        var doubleTicksSpacePlusTick = false
        
        resetTickEndingPointers()
        
        possibleClosingTick = -1
        literalBackTicks = []
        
        var next = forChunkAt + 1
        var lookingForClosingTicks = true
        while lookingForClosingTicks && next < chunks.count {
            let nextChunk = chunks[next]
            if nextChunk.type == .backtickQuote {
                if next == forChunkAt + 1 {
                    doubleTicks = true
                } else if next == forChunkAt + 3 && doubleTicksPlusSpace {
                    doubleTicksSpacePlusTick = true
                    tickBeforeSpace = next
                } else if doubleTicksSpacePlusTick {
                    if tickBeforeSpace < 0 {
                        tickBeforeSpace = next
                        setPossibleClosingTick(next)
                    } else if next == spaceAfterTick + 1 {
                        closingTick1 = next
                        setPossibleClosingTick(next)
                    } else if next == closingTick1 + 1 {
                        closingTick2 = next
                        lookingForClosingTicks = false
                        possibleClosingTick = -1
                    }
                } else if doubleTicks {
                    if next == closingTick1 + 1 {
                        closingTick2 = next
                        lookingForClosingTicks = false
                        possibleClosingTick = -1
                    } else {
                        closingTick1 = next
                        setPossibleClosingTick(next)
                    }
                } else {
                    closingTick1 = next
                    lookingForClosingTicks = false
                }
            } else if nextChunk.text == " " {
                if next == forChunkAt + 2 {
                    doubleTicksPlusSpace = true
                } else if doubleTicksSpacePlusTick
                    && tickBeforeSpace > 0
                    && spaceAfterTick < 0 {
                    spaceAfterTick = next
                } else {
                    checkForPossibleClosingTick()
                    resetTickEndingPointers()
                }
            } else {
                checkForPossibleClosingTick()
                resetTickEndingPointers()
            }
            next += 1
        }
        
        guard !lookingForClosingTicks else { return }
        
        if doubleTicksSpacePlusTick {
            chunks[forChunkAt].type = .startCode
            chunks[forChunkAt + 1].type = .backtickQuote2
            chunks[forChunkAt + 2].type = .skipSpace
            chunks[forChunkAt + 3].type = .literal
            chunks[tickBeforeSpace].type = .literal
            chunks[spaceAfterTick].type = .skipSpace
            chunks[closingTick1].type = .endCode
            chunks[closingTick2].type = .backtickQuote2
            setLiteralBackTicks()
        } else if doubleTicks {
            chunks[forChunkAt].type = .startCode
            chunks[forChunkAt + 1].type = .backtickQuote2
            chunks[closingTick1].type = .endCode
            chunks[closingTick2].type = .backtickQuote2
            setLiteralBackTicks()
        } else {
            chunks[forChunkAt].type = .startCode
            chunks[closingTick1].type = .endCode
        }
    }
    
    func setLiteralBackTicks() {
        for index in literalBackTicks {
            let backTickChunk = chunks[index]
            if backTickChunk.type == .backtickQuote {
                backTickChunk.type = .literal
            }
        }
    }
    
    func resetTickEndingPointers() {
        tickBeforeSpace = -1
        spaceAfterTick = -1
        closingTick1 = -1
        closingTick2 = -1
    }
    
    func setPossibleClosingTick(_ tickPosition: Int) {
        checkForPossibleClosingTick()
        possibleClosingTick = tickPosition
    }
    
    /// If we have a possible closing backtick that turned out not to be part of a closure, then
    /// let's add it to our list for possible later action.
    func checkForPossibleClosingTick() {
        if possibleClosingTick > 0 {
            literalBackTicks.append(possibleClosingTick)
        }
        possibleClosingTick = -1
    }
    
    /// If we have a left square bracket, scan for other punctuation related to a link.
    func scanForLinkElements(forChunkAt: Int) {
        // See if this is an image rather than a hyperlink.
        var exclamationMark: MkdownChunk?
        if forChunkAt > 0 && chunks[forChunkAt - 1].type == .exclamationMark {
            exclamationMark = chunks[forChunkAt - 1]
        }
        
        let leftBracket1 = chunks[forChunkAt]
        var caret: MkdownChunk?
        var poundSign: MkdownChunk?
        var leftBracket2: MkdownChunk?
        var rightBracket1: MkdownChunk?
        var rightBracket2: MkdownChunk?
        var closingTextBracketIndex = -1
        var leftLabelBracket: MkdownChunk?
        var leftLabelBracketIndex = -1
        var rightLabelBracket: MkdownChunk?
        var leftParen: MkdownChunk?
        var leftQuote: MkdownChunk?
        var rightQuote: MkdownChunk?
        var rightParen: MkdownChunk?
        var lastChunk = MkdownChunk()
        var enclosedParens = 0
        
        var doubleBrackets = false
        var footnoteRef = false
        var citationRef = false
        var textBracketsClosed = false
        var linkLooking = true
        var index = forChunkAt + 1
        while linkLooking && index < chunks.count {
            let chunk = chunks[index]
            switch chunk.type {
            case .caret:
                if index == forChunkAt + 1 {
                    caret = chunk
                    footnoteRef = true
                }
            case .poundSign:
                if index == forChunkAt + 1 {
                    poundSign = chunk
                    citationRef = true
                } else if (index == leftLabelBracketIndex + 1) {
                    poundSign = chunk
                    citationRef = true
                }
            case .leftSquareBracket:
                if index == forChunkAt + 1 {
                    leftBracket2 = chunk
                    doubleBrackets = true
                } else if (textBracketsClosed
                    && !doubleBrackets
                    && (index == closingTextBracketIndex + 1
                        || (index == closingTextBracketIndex + 2
                            && lastChunk.text == " "))) {
                    leftLabelBracket = chunk
                    leftLabelBracketIndex = index
                } else {
                    return
                }
            case .rightSquareBracket:
                if rightBracket1 == nil {
                    rightBracket1 = chunk
                    if footnoteRef {
                        textBracketsClosed = true
                        closingTextBracketIndex = index
                        linkLooking = false
                    } else if citationRef {
                        textBracketsClosed = true
                        closingTextBracketIndex = index
                        linkLooking = false
                    } else if !doubleBrackets {
                        textBracketsClosed = true
                        closingTextBracketIndex = index
                    }
                } else if doubleBrackets && rightBracket2 == nil {
                    rightBracket2 = chunk
                    textBracketsClosed = true
                    linkLooking = false
                    closingTextBracketIndex = index
                } else if leftLabelBracket != nil {
                    rightLabelBracket = chunk
                    linkLooking = false
                } else {
                    return
                }
            case .plaintext:
                if textBracketsClosed && leftParen == nil && leftLabelBracket == nil {
                    if chunk.text == " " {
                        break
                    } else {
                        return
                    }
                }
            case .leftParen:
                if citationRef {
                    // ignore parens
                } else if textBracketsClosed && leftParen == nil {
                    leftParen = chunk
                } else {
                    enclosedParens += 1
                }
            case .rightParen:
                if citationRef {
                    // ignore parens
                } else if enclosedParens > 0 {
                    enclosedParens -= 1
                } else if leftParen == nil {
                    return
                } else {
                    rightParen = chunk
                    linkLooking = false
                }
            case .singleQuote:
                if citationRef {
                    // don't care about quote chars
                } else if leftQuote == nil && textBracketsClosed && leftParen != nil {
                    leftQuote = chunk
                } else if leftQuote != nil && leftQuote!.type == chunk.type {
                    rightQuote = chunk
                }
            case .doubleQuote:
                if citationRef {
                    // don't care about quote chars
                } else if leftQuote == nil && textBracketsClosed && leftParen != nil {
                    leftQuote = chunk
                } else if leftQuote != nil && leftQuote!.type == chunk.type {
                    rightQuote = chunk
                }
            default:
                break
            }
            lastChunk = chunk
            index += 1
        }
        
        if linkLooking { return }
        
        if footnoteRef {
            leftBracket1.type = .startFootnoteLabel1
            caret!.type = .startFootnoteLabel2
            rightBracket1!.type = .endFootnoteLabel
        } else if citationRef {
            if rightLabelBracket == nil {
                leftBracket1.type = .startCitationLabel1
                poundSign!.type = .startCitationLabel2
                rightBracket1!.type = .endCitationLabel
            } else {
                leftBracket1.type = .startCitationLocator
                rightBracket1!.type = .endCitationLocator
                leftLabelBracket!.type = .startCitationLabel1
                poundSign!.type = .startCitationLabel2
                rightLabelBracket!.type = .endCitationLabel
            }
        } else if doubleBrackets {
            leftBracket1.type = .startWikiLink1
            leftBracket2!.type = .startWikiLink2
            rightBracket1!.type = .endWikiLink1
            rightBracket2!.type = .endWikiLink2
        } else {
            if exclamationMark != nil {
                exclamationMark!.type = .startImage
            }
            leftBracket1.type = .startLinkText
            rightBracket1!.type = .endLinkText
            if leftParen != nil {
                leftParen!.type = .startLink
                rightParen!.type = .endLink
                if leftQuote != nil && rightQuote != nil {
                    leftQuote!.type = .startTitle
                    rightQuote!.type = .endTitle
                }
            } else if leftLabelBracket != nil {
                leftLabelBracket!.type = .startLinkLabel
                rightLabelBracket!.type = .endLinkLabel
            }
        }
    }
    
    // ===========================================================
    //
    // Section 2.c - Send the chunks to the writer.
    //
    // ===========================================================
    
    var imageNotLink = false
    var linkTextChunks: [MkdownChunk] = []
    var linkText = ""
    var doubleBrackets = false
    var linkElementDiverter: LinkElementDiverter = .na
    var linkTitle = ""
    var linkLabel = ""
    var linkURL = ""
    
    var autoLink = ""
    var autoLinkSep: Character = " "
    
    var footnoteText = false
    var citationText = false
    var citationLocatorSpan = false
    var citationLocator = ""

    /// Go through the chunks and write each one. 
    func writeChunks(chunksToWrite: [MkdownChunk]) {
        withinCodeSpan = false
        backslashed = false
        footnote = MkdownFootnote()
        citation = MkdownCitation()
        for chunkToWrite in chunksToWrite {
            if chunkToWrite.type == .startCode {
                withinCodeSpan = true
            } else if chunkToWrite.type == .endCode {
                withinCodeSpan = false
            }
            write(chunk: chunkToWrite)
        }
    }
    
    /// Write out a single chunk.
    func write(chunk: MkdownChunk) {
        
        // If we're in the middle of a link, then capture the text for its
        // various elements instead of writing anything out in the normal
        // linear flow.
        
        if linkElementDiverter != .na {
            switch linkElementDiverter {
            case .text:
                if chunk.type == .endLinkText || chunk.type == .endWikiLink1 {
                    linkElementDiverter = .na
                } else {
                    linkTextChunks.append(chunk)
                    linkText.append(chunk.text)
                    return
                }
            case .url:
                if chunk.type == .endLink || chunk.type == .startTitle || chunk.text == " " {
                    linkElementDiverter = .na
                } else {
                    linkURL.append(chunk.text)
                    return
                }
            case .title:
                if chunk.type == .endTitle || chunk.type == .endLink {
                    linkElementDiverter = .na
                } else {
                    linkTitle.append(chunk.text)
                    return
                }
            case .label:
                if chunk.type == .endLinkLabel {
                    linkElementDiverter = .na
                } else {
                    linkLabel.append(chunk.text.lowercased())
                    return
                }
            case .autoLink:
                if chunk.type == .autoLinkEnd {
                    linkElementDiverter = .na
                } else {
                    autoLink.append(chunk.text)
                    if chunk.type == .atSign {
                        autoLinkSep = "@"
                    } else if chunk.type == .colon {
                        autoLinkSep = ":"
                    }
                    return
                }
            case .na:
                break
            }

        }
        
        // If we're calling out a footnote, collect the text here.
        if footnoteText && chunk.type != .endFootnoteLabel {
            footnote.label.append(chunk.text)
            return
        }
        
        // If we're calling out a citation, collect the text here.
        if citationText && chunk.type != .endCitationLabel {
            citation.label.append(chunk.text)
            return
        }
        
        if citationLocatorSpan && chunk.type != .endCitationLocator {
            citationLocator.append(chunk.text)
            return
        }
        
        // Figure out what to do with the next chunk of text,
        // depending on its type.
        if backslashed {
            writer.append(chunk.text)
            backslashed = false
        } else {
            switch chunk.type {
            case .ampersand:
                writer.writeAmpersand()
            case .backSlash:
                if withinCodeSpan {
                    writer.write("\\")
                } else {
                    backslashed = true
                }
            case .leftAngleBracket:
                writer.writeLeftAngleBracket()
            case .rightAngleBracket:
                if withinCodeSpan {
                    writer.writeRightAngleBracket()
                } else {
                    writer.write(">")
                }
            case .startEmphasis:
                writer.startEmphasis()
            case .endEmphasis:
                writer.finishEmphasis()
            case .startStrong1:
                writer.startStrong()
            case .startStrong2:
                break
            case .endStrong1:
                writer.finishStrong()
            case .endStrong2:
                break
            case .startFootnoteLabel1:
                break
            case .startFootnoteLabel2:
                footnote = MkdownFootnote()
                footnoteText = true
            case .endFootnoteLabel:
                footnote.inputLine = chunk.text
                let assignedNumber = addFootnote()
                writer.openTag("a")
                writer.addHref("#fn:\(assignedNumber)")
                writer.addID("fnref:\(assignedNumber)")
                writer.addTitle("see footnote")
                writer.addClass("footnote")
                writer.closeTag()
                writer.append("[\(assignedNumber)]")
                writer.finishLink()
                footnoteText = false
            case .startCitationLocator:
                citationLocator = ""
                citationLocatorSpan = true
            case .endCitationLocator:
                citationLocatorSpan = false
            case .startCitationLabel1:
                break
            case .startCitationLabel2:
                citation = MkdownCitation()
                citationText = true
            case .endCitationLabel:
                citation.inputLine = chunk.text
                let commonLocator = StringUtils.toCommon(citationLocator)
                if commonLocator == "notcited" || commonLocator == "nocite" {
                    citation.cited = false
                }
                let assignedNumber = addCitation()
                if citation.cited {
                    writer.openTag("a")
                    writer.addHref("#cn:\(assignedNumber)")
                    writer.addID("cnref:\(assignedNumber)")
                    writer.addTitle("see citation")
                    writer.addClass("citation")
                    writer.closeTag()
                    writer.append("(")
                    if commonLocator.count > 0 {
                        writer.append("\(citationLocator), ")
                    }
                    writer.append("\(assignedNumber))")
                    writer.finishLink()
                }
                citationText = false
                citationLocator = ""
                citationLocatorSpan = false
            case .startImage:
                imageNotLink = true
            case .startLinkText:
                linkTextChunks = []
                linkText = ""
                linkElementDiverter = .text
            case .startWikiLink1:
                break
            case .startWikiLink2:
                linkTextChunks = []
                linkText = ""
                linkElementDiverter = .text
                doubleBrackets = true
            case .endWikiLink1:
                break
            case .endWikiLink2:
                finishLink()
            case .endLinkText:
                linkElementDiverter = .na
            case .startLink:
                linkElementDiverter = .url
                linkURL = ""
            case .startTitle:
                linkElementDiverter = .title
                linkTitle = ""
            case .endTitle:
                linkElementDiverter = .na
            case .endLink:
                linkElementDiverter = .na
                finishLink()
            case .startLinkLabel:
                linkElementDiverter = .label
                linkLabel = ""
            case .endLinkLabel:
                linkElementDiverter = .na
                finishLink()
            case .autoLinkStart:
                linkElementDiverter = .autoLink
                autoLink = ""
                autoLinkSep = " "
            case .autoLinkEnd:
                finishAutoLink()
            case .backtickQuote:
                writer.append("`")
            case .startMath:
                writer.append("\\(")
            case .endMath:
                writer.append("\\)")
            case .skipMath:
                break
            case .startCode:
                writer.startCode()
            case .endCode:
                writer.finishCode()
            case .backtickQuote2:
                break
            case .skipSpace:
                break
            case .ellipsis:
                writer.ellipsis()
            case .endash:
                writer.writeEnDash()
            case .emdash:
                writer.writeEmDash()
            case .singleCurlyQuoteOpen:
                writer.leftSingleQuote()
            case .singleCurlyQuoteClose:
                writer.rightSingleQuote()
            case .doubleCurlyQuoteOpen:
                writer.leftDoubleQuote()
            case .doubleCurlyQuoteClose:
                writer.rightDoubleQuote()
            default:
                writer.append(chunk.text)
            }
        }
    }
    
    /// Increment for each new footnote reference found in text.
    var footnoteNumber = 0
    
    /// Increment for each new citation reference found in text.
    var citationNumber = 0
    
    /// Add another footnote to the list and return its assigned number.
    func addFootnote() -> Int {
        
        var number = 0
        if footnote.text.count == 0 {
            footnoteNumber += 1
            footnote.number = footnoteNumber
        }
        let searchFor = footnote.label.lowercased()
        var i = 0
        while i < footnotes.count {
            if searchFor == footnotes[i].label {
                if footnote.text.count > 0 {
                    footnotes[i].text = footnote.text
                    number = footnotes[i].number
                } else if footnote.number > 0 {
                    footnotes[i].number = footnote.number
                    number = footnote.number
                }
                if footnote.inputLine.count > 0 && footnotes[i].inputLine.count == 0 {
                    footnotes[i].inputLine = footnote.inputLine
                }
                footnote = footnotes[i]
                break
            }
            i += 1
        }
        if i >= footnotes.count {
            footnotes.append(footnote)
            number = footnote.number
        }
        return number
    }
    
    /// Add another citation to the list and return its assigned number.
    func addCitation() -> Int {
        
        var number = 0
        let searchFor = citation.label.lowercased()
        var i = 0
        while i < citations.count {
            if searchFor == citations[i].label.lowercased() {
                if citation.number == 0 && citations[i].number == 0 {
                    citationNumber += 1
                    number = citationNumber
                    citations[i].number = number
                    citation.number = number
                } else if citations[i].number > 0 {
                    number = citations[i].number
                    citation.number = number
                } else {
                    number = citation.number
                    citations[i].number = number
                }
                if citation.text.count > 0 {
                    citations[i].text = citation.text
                }
                if citation.inputLine.count > 0 && citations[i].inputLine.count == 0 {
                    citations[i].inputLine = citation.inputLine
                }
                if !citation.cited {
                    citations[i].cited = citation.cited
                }
                citation = citations[i]
                break
            }
            i += 1
        }
        if i >= citations.count {
            if citation.number == 0 && citation.text.count == 0 {
                citationNumber += 1
                citation.number = citationNumber
            }
            citations.append(citation)
            number = citation.number
        }
        return number
    }
    
    func finishAutoLink() {
        if autoLinkSep == ":" {
            writer.link(text: autoLink, path: autoLink)
        } else {
            writer.link(text: autoLink, path: "mailto:\(autoLink)")
        }
    }
        
    func initLink() {
        imageNotLink = false
        linkTextChunks = []
        linkText = ""
        doubleBrackets = false
        linkElementDiverter = .na
        linkTitle = ""
        linkLabel = ""
        linkURL = ""
    }
    
    func finishLink() {
        
        // If this is a wiki style link, then format the URL from the text.
        if doubleBrackets {
            linkURL = assembleWikiLink(title: linkText)
        }

        // If this is a reference style link, then let's look it up in the dictionary.
        if linkURL.count == 0 {
            if linkLabel.count == 0 {
                linkLabel = linkText.lowercased()
            }
            let refLink = linkDict[linkLabel]
            if refLink != nil {
                linkURL = refLink!.link
                linkTitle = refLink!.title
            }
        }
        
        if linkURL.hasPrefix("<") && linkURL.hasSuffix(">") {
            let linkStart = linkURL.index(after: linkURL.startIndex)
            let linkEnd = linkURL.index(before: linkURL.endIndex)
            linkURL = String(linkURL[linkStart..<linkEnd])
        }
        
        if imageNotLink {
            writer.image(text: linkText, path: linkURL, title: linkTitle)
        } else {
            writer.startLink(path: linkURL, title: linkTitle)
            writeChunks(chunksToWrite: linkTextChunks)
            writer.finishLink()
        }
        initLink()
    }
    
    func assembleWikiLink(title: String) -> String {

        /* let formattedTitle = formatWikiLink(title)
        
        var link = formattedTitle
        if wikiLinkLookup != nil {
            link = wikiLinkLookup!.mkdownWikiLinkLookup(linkText: formattedTitle)
            link = formatWikiLink(link)
        }
        return wikiLinkPrefix + link + wikiLinkSuffix */
        
        var linkTargetTitle = title
        if mkdownContext != nil {
            linkTargetTitle = mkdownContext!.mkdownWikiLinkLookup(linkText: title)
        }
        return options.wikiLinkPrefix + formatWikiLink(linkTargetTitle) + options.wikiLinkSuffix
    }
    
    func formatWikiLink(_ title: String) -> String {
        switch options.wikiLinkFormatting {
        case .common:
            return StringUtils.toCommon(title)
        case .fileName:
            return StringUtils.toCommonFileName(title)
        }
    }
    
    enum LinkElementDiverter {
        case na
        case text
        case label
        case title
        case url
        case autoLink
    }
    
}
