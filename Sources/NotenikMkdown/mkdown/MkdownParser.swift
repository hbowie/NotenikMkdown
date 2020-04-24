//
//  MkdownParser.swift
//  Notenik
//
//  Created by Herb Bowie on 2/25/20.
//  Copyright © 2020 Herb Bowie (https://powersurgepub.com)
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
    
    
    let interNoteDomain = "https://ntnk.app/"
    var wikiLinkPrefix = ""
    var wikiLinkSuffix = ""
    var wikiLinkFormatting: WikiLinkFormat = .common
    var wikiLinkLookup: MkdownWikiLinkLookup?
    
    var nextIndex: String.Index
    
    var nextLine = MkdownLine()
    var lastLine = MkdownLine()
    var lastNonBlankLine = MkdownLine()
    
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
    
    var linkLabelPhase: LinkLabelDefPhase = .na
    var angleBracketsUsed = false
    var titleEndChar: Character = " "
    
    var refLink = RefLink()
    
    var headingNumbers = [0, 0, 0, 0, 0, 0, 0]
    
    var indentToCode = false
    
    /// A static utility function to convert markdown to HTML and write it to an instance of Markedup. 
    public static func markdownToMarkedup(markdown: String,
                                          wikiLinkLookup: MkdownWikiLinkLookup?,
                                          writer: Markedup) {
        let md = MkdownParser(markdown)
        md.wikiLinkLookup = wikiLinkLookup
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
        wikiLinkPrefix = interNoteDomain
    }
    
    /// Initialize with a string that will be copied.
    public init(_ mkdown: String) {
        self.mkdown = mkdown
        nextIndex = self.mkdown.startIndex
        startText = nextIndex
        startLine = nextIndex
        endLine = nextIndex
        endText = nextIndex
        startNumber = nextIndex
        startBullet = nextIndex
        wikiLinkPrefix = interNoteDomain
    }
    
    /// Try to initialize by reading input from a URL.
    public init?(_ url: URL) {
        do {
            try mkdown = String(contentsOf: url)
            nextIndex = mkdown.startIndex
            startText = nextIndex
            startLine = nextIndex
            endLine = nextIndex
            endText = nextIndex
            startNumber = nextIndex
            startBullet = nextIndex
            wikiLinkPrefix = interNoteDomain
        } catch {
            print("Error is \(error)")
            return nil
        }
    }
    
    /// If using wiki-style links, set the formatting options before performing the parse operation.
    public func setWikiLinkFormatting(prefix: String,
                               format: WikiLinkFormat,
                               suffix: String,
                               lookup: MkdownWikiLinkLookup? = nil) {
        self.wikiLinkPrefix = prefix
        self.wikiLinkFormatting = format
        self.wikiLinkSuffix = suffix
        self.wikiLinkLookup = lookup
    }
    
    /// Perform the parsing.
    public func parse() {
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
        
        nextIndex = mkdown.startIndex
        beginLine()
        
        while nextIndex < mkdown.endIndex {
             
            // Get the next character and adjust indices
            let char = mkdown[nextIndex]
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
            
            // Check for a line of all dashes or all equal signs
            if (char == "-" || char == "=" || char == "*" || char == "_")
                && (nextLine.repeatingChar == " " || nextLine.repeatingChar == char) {
                nextLine.repeatingChar = char
                nextLine.repeatCount += 1
            } else if char == " " {
                nextLine.onlyRepeating = false
            } else if char == ">" && phase == .leadingPunctuation {
                // Blockquotes make no difference
            } else {
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
                } else if char == " " && spaceCount < 3 {
                    spaceCount += 1
                    continue
                } else {
                    spaceCount = 0
                    if char == "\t" || char == " " {
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
                    } else if char.isNumber {
                        if following && followingType != .orderedItem {
                            phase = .text
                        } else {
                            leadingNumber = true
                            startNumber = lastIndex
                            continue
                        }
                    } else if char == "[" && nextLine.indentLevels < 1 {
                        linkLabelPhase = .leftBracket
                        refLink = RefLink()
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
                    case .ordinaryText, .followOn, .orderedItem, .unorderedItem:
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
            }
            
        } // end of mkdown input
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
        startNumber = nextIndex
        startBullet = nextIndex
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
    }
    
    /// Wrap up initial examination of the line and figure out what to do with it.
    func finishLine() {
        
        // Capture the entire line for later processing.
        if endLine > startLine {
            nextLine.line = String(mkdown[startLine..<endLine])
        }
        
        // Figure out some of the less ordinary line types.
        if nextLine.type == .code {
            // Don't bother looking for other indicators
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
        
        switch nextLine.type {
        case .h1Underlines, .h2Underlines, .linkDef, .linkDefExt:
            break
        case .blank:
            if lastLine.type == .blank { break }
            lines.append(nextLine)
            lastLine = nextLine
        default:
            lines.append(nextLine)
            lastLine = nextLine
            lastNonBlankLine = nextLine
        }

    }
    
    func linkLabelExamineChar(_ char: Character) {
         
         switch linkLabelPhase {
         case .na:
             break
         case .leftBracket:
             if char == "[" && refLink.label.count == 0 {
                 break
             } else if char == "]" {
                 linkLabelPhase = .rightBracket
             } else {
                 refLink.label.append(char.lowercased())
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
                 } else {
                     refLink.link.append(char)
                     linkLabelPhase = .linkStart
                 }
             }
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
    var lines:    [MkdownLine] = []

    // ===========================================================
    //
    // Phase 2 - Take the lines and convert them to HTML output.
    //
    // ===========================================================
    
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
    
    var backslashed = false
    
    var openBlocks = MkdownBlockStack()
    
    /// Now that we have the input divided into lines, and the lines assigned types,
    /// let's generate the output HTML.
    func linesOut() {
        
        writer = Markedup()
        // writer.comment("Markdown to HTML conversion provided by NotenikMkdown")
        lastQuoteLevel = 0
        openBlocks = MkdownBlockStack()
        
        for line in lines {
            
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
                    openBlock(blockToOpen.tag)
                    openBlocks.append(blockToOpen)
                    blockToOpenIndex += 1
                }
                
                if listItemIndex > 0 {
                    let listIndex = listItemIndex - 1
                    let listBlock = openBlocks.blocks[listIndex]
                    if listBlock.isListTag && listBlock.listWithParagraphs {
                        let paraBlock = MkdownBlock("p")
                        openBlock(paraBlock.tag)
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
            case .orderedItem, .unorderedItem:
                textToChunks(line)
            case .followOn:
                textToChunks(line)
            default:
                break
            }
        }
        closeBlocks(from: 0)
    }
    
    func openBlock(_ tag: String) {
        outputUnwrittenChunks()
        switch tag {
        case "blockquote":
            writer.startBlockQuote()
        case "code":
            writer.startCode()
        case "h1":
            writer.startHeading(level: 1)
        case "h2":
            writer.startHeading(level: 2)
        case "h3":
            writer.startHeading(level: 3)
        case "h4":
            writer.startHeading(level: 4)
        case "h5":
            writer.startHeading(level: 5)
        case "h6":
            writer.startHeading(level: 6)
        case "li":
            writer.startListItem()
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
            closeBlock(tag: openBlocks.blocks[blockToClose].tag)
            openBlocks.removeLast()
            blockToClose -= 1
        }
    }
    
    func closeBlock(tag: String) {
        outputChunks()
        switch tag {
        case "blockquote":
            writer.finishBlockQuote()
        case "code":
            writer.finishCode()
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
                case "]":
                    addCharAsChunk(char: char, type: .rightSquareBracket, lastChar: lastChar, line: line)
                case "(":
                    addCharAsChunk(char: char, type: .leftParen, lastChar: lastChar, line: line)
                case ")":
                    addCharAsChunk(char: char, type: .rightParen, lastChar: lastChar, line: line)
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
                    }
                    nextChunk.endsWithSpace = true
                    appendToNextChunk(char: char, lastChar: lastChar, line: line)
                default:
                    appendToNextChunk(char: char, lastChar: lastChar, line: line)
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
    var withinTag = false
    
    /// Scan through our accumulated chunks, looking for meaningful patterns of puncutation.
    func identifyPatterns() {
        
        withinCodeSpan = false
        var index = 0
        while index < chunks.count {
            let chunk = chunks[index]
            let nextIndex = index + 1
            switch chunk.type {
            case .asterisk, .underline:
                if chunk.lineType == .code { break }
                if withinCodeSpan { break }
                if withinTag { break }
                scanForEmphasisClosure(forChunkAt: index)
            case .leftAngleBracket:
                if chunk.lineType == .code { break }
                if withinCodeSpan { break }
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
                if withinTag { break }
                if nextIndex >= chunks.count { break }
                if chunks[nextIndex].startsWithSpace { break }
                chunk.type = .entityStart
            case .leftSquareBracket:
                if chunk.lineType == .code { break }
                if withinCodeSpan { break }
                if withinTag { break }
                scanForLinkElements(forChunkAt: index)
            case .backtickQuote:
                scanForCodeClosure(forChunkAt: index)
                if chunk.type == .startCode {
                    withinCodeSpan = true
                }
            case .singleQuote, .doubleQuote:
                if withinTag { break }
                if withinCodeSpan { break }
                scanForQuotes(forChunkAt: index)
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
        guard forChunkAt + 4 < chunks.count else { return false }
        guard chunks[forChunkAt + 4].type == .rightAngleBracket else { return false }
        var sep: Character = " "
        switch chunks[forChunkAt + 2].type {
        case .atSign:
            sep = "@"
        case .colon:
            sep = ":"
        default:
            sep = " "
        }
        guard sep == ":" || sep == "@" else { return false }
        let part1 = chunks[forChunkAt + 1].text
        if sep == ":" && part1 != "http" && part1 != "https" { return false }
        chunks[forChunkAt].type = .autoLinkStart
        chunks[forChunkAt + 4].type = .autoLinkEnd
        return true
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
        
        // See if this is an image, rather than a hyperlink.
        var exclamationMark: MkdownChunk?
        if forChunkAt > 0 && chunks[forChunkAt - 1].type == .exclamationMark {
            exclamationMark = chunks[forChunkAt - 1]
        }
        
        let leftBracket1 = chunks[forChunkAt]
        var leftBracket2: MkdownChunk?
        var rightBracket1: MkdownChunk?
        var rightBracket2: MkdownChunk?
        var closingTextBracketIndex = -1
        var leftLabelBracket: MkdownChunk?
        var rightLabelBracket: MkdownChunk?
        var leftParen: MkdownChunk?
        var leftQuote: MkdownChunk?
        var rightQuote: MkdownChunk?
        var rightParen: MkdownChunk?
        var lastChunk = MkdownChunk()
        var enclosedParens = 0
        
        var doubleBrackets = false
        var textBracketsClosed = false
        var linkLooking = true
        var index = forChunkAt + 1
        while linkLooking && index < chunks.count {
            let chunk = chunks[index]
            switch chunk.type {
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
                } else {
                    return
                }
            case .rightSquareBracket:
                if rightBracket1 == nil {
                    rightBracket1 = chunk
                    if !doubleBrackets {
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
                if textBracketsClosed && leftParen == nil {
                    leftParen = chunk
                } else {
                    enclosedParens += 1
                }
            case .rightParen:
                if leftParen == nil {
                    return
                } else if enclosedParens > 0 {
                    enclosedParens -= 1
                } else {
                    rightParen = chunk
                    linkLooking = false
                }
            case .singleQuote:
                if leftQuote == nil && textBracketsClosed && leftParen != nil {
                    leftQuote = chunk
                } else if leftQuote != nil && leftQuote!.type == chunk.type {
                    rightQuote = chunk
                }
            case .doubleQuote:
                if leftQuote == nil && textBracketsClosed && leftParen != nil {
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
        
        if doubleBrackets {
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

    /// Go through the chunks and write each one. 
    func writeChunks(chunksToWrite: [MkdownChunk]) {
        withinCodeSpan = false
        backslashed = false
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
        var formattedTitle = ""
        switch wikiLinkFormatting {
        case .common:
            formattedTitle = StringUtils.toCommon(title)
        case .fileName:
            formattedTitle = StringUtils.toCommonFileName(title)
        }
        
        var link = formattedTitle
        if wikiLinkLookup != nil {
            link = wikiLinkLookup!.mkdownWikiLinkLookup(title: formattedTitle)
        }
        return wikiLinkPrefix + link + wikiLinkSuffix
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
