//
//  MkdownParser.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 2/25/20.
//  Copyright © 2020 - 2025 Herb Bowie (https://hbowie.net)
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
    
    var mdin = MkdownInputStack()
    var textToInclude: String? = nil
    
    public var options = MkdownOptions()
    
    public var mkdownContext: MkdownContext?
    
    var nextLine = MkdownLine()
    var lastLine = MkdownLine()
    var lastNonBlankLine = MkdownLine()
    var lastBlankLine = MkdownLine()
    var lastDefLine = MkdownLine()
    var nonDefCount = 3
    
    var lineIndex = -1

    var phase:     MkdownLinePhase = .leadingPunctuation
    var spaceCount = 0
    var charFollowingHashMarks: Character? = nil
    
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
    
    var linkLabelPhase: LinkLabelDefPhase = .na
    var angleBracketsUsed = false
    var titleEndChar: Character = " "
    
    var refLink = RefLink()
    
    var footnote = MkdownFootnote()
    var withinFootnote = false
    
    var citation = MkdownCitation()
    var withinCitation = false
    
    var withinFigure = false
    
    var headingNumbers = [0, 0, 0, 0, 0, 0, 0]
    
    var indentToCode = false
    
    var codeFenced = false
    var codeFenceChar: Character = " "
    var codeFenceRepeatCount = 0
    
    var mathBlock = false
    var mathBlockStart = ""
    var mathBlockStartSaved = ""
    var mathBlockEnd = ""
    var mathLineEndTrailingWhiteSpace = false
    var mathBlockValidStart: Bool {
        return mathBlockStart == "$$" || mathBlockStart == "\\\\["
    }
    
    var tableStarted = false
    var tableSortable = false
    var tableID = ""
    var tableNumber = 0
    var columnStyles: [String] = []
    var columnIndex = 0
    
    var sectionOpen = false
    var sectionHeadingLevel = -1
    
    var injectElement = ""
    var injectKlass = ""
    var injectID = ""
    var injectStyle = ""
    
    public var counts = MkdownCounts()
    
    // -----------------------------------------------------------
    //
    // MARK: Initialization.
    //
    // -----------------------------------------------------------
    
    /// Initialize with an empty string.
    public init() {
        mdin = MkdownInputStack()
    }
    
    public convenience init(options: MkdownOptions) {
        self.init()
        self.options = options
    }
    
    /// Initialize with a string that will be copied.
    public convenience init(_ mkdown: String, options: MkdownOptions, context: MkdownContext? = nil) {
        self.init()
        mdin = MkdownInputStack(mkdown)
        self.options = options
        self.mkdownContext = context
    }
    
    /// Try to initialize by reading input from a URL.
    public convenience init?(_ url: URL) {
        self.init()
        do {
            let mkdown = try String(contentsOf: url)
            mdin = MkdownInputStack(mkdown)
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
        options.wikiLinks.set(format: format, prefix: prefix, suffix: suffix)
        mkdownContext = context
    }
    
    /// Perform the parsing.
    public func parse() {
        
        counts.size = mdin.count
        counts.lines = 0
        counts.words = 0
        counts.text = 0
        
        mdToLines()
        linesOut()
    }
    
    // -----------------------------------------------------------
    //
    // MARK: Phase 1 - Parse the input block of Markdown text, and
    // break down into lines.
    //
    // -----------------------------------------------------------
    
    /// Make our first pass through the Markdown, identifying basic info about each line.
    func mdToLines() {
        
        withinFootnote = false
        withinCitation = false
        withinFigure = false
        codeFenced = false
        mathBlock = false
        mathBlockStart = ""
        mathBlockStartSaved = ""
        mathBlockEnd = ""
        mathLineEndTrailingWhiteSpace = false
        mdin.reset()
        beginLine()
        
        while mdin.moreChars {
             
            // Get the next character and adjust indices
            guard let char = mdin.nextChar() else { break }
            
            lineIndex += 1
            
            // Deal with end of line
            if char.isNewline {
                nextLine.endsWithNewline = true
                finishLine()
                pushAndPopIncludes()
                beginLine()
                continue
            }
            
            mdin.setIndex(.endLine, to: .next)
            
            // Check for a line consisting of a repetition of a single character.
            if nextLine.repeatingStart.isEmpty {
                nextLine.repeatingStart.append(char)
                nextLine.stillRepeating = true
            } else if char == nextLine.repeatingStart.first && nextLine.stillRepeating {
                nextLine.repeatingStart.append(char)
            } else {
                nextLine.stillRepeating = false
            }
            
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
                    case "figure", "figcaption":
                        goodTag = true
                    case "script":
                        goodTag = true
                    case "!--":
                        goodTag = true
                    case "details", "summary":
                        goodTag = true
                    case "section", "article", "aside":
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
            
            // Check for table lines. 
            if nextLine.leadingPipe {
                if char == "|" {
                    nextLine.pipeCount += 1
                } else if char == "-" {
                    nextLine.dashCount += 1
                } else if char == ":" {
                    //
                } else if char.isWhitespace {
                    //
                } else {
                    nextLine.onlyTableDelimChars = false
                }
            }
            
            // Check the beginning of the line for significant characters.
            if phase == .leadingPunctuation {
                // mdin.setIndex(.endText, to: .next)
                if openHTMLblock {
                    phase = .text
                    nextLine.makeHTML()
                } else if mathBlock && !char.isWhitespace {
                    phase = .text
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
                        mdin.setIndex(.startText, to: .startNumber)
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
                        mdin.setIndex(.startText, to: .startNumber)
                    }
                } else if nextLine.leadingBulletAndSpace {
                    if char.isWhitespace {
                        continue
                    } else {
                        if char == "[" {
                            nextLine.checkBox.append(char)
                        }
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
                        mdin.setIndex(.startText, to: .startBullet)
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
                        mdin.setIndex(.startText, to: .startColon)
                    }
                } else if nextLine.hashCount > 0 {
                    if char.isWhitespace {
                        charFollowingHashMarks = char
                        continue
                    } else if char == "#" && charFollowingHashMarks == nil {
                        _ = nextLine.incrementHashCount()
                    } else {
                        if charFollowingHashMarks == nil {
                            charFollowingHashMarks = char
                        }
                        phase = .text
                    }
                } else if codeFenced {
                    phase = .text
                    nextLine.textFound = true
                } else if mathBlockStart.count > 0 {
                    var abort = false
                    var persevere = false
                    var done = false
                    switch char {
                    case "$":
                        if mathBlockStart == "$" {
                            done = true
                        } else {
                            abort = true
                        }
                    case "\\":
                        if mathBlockStart == "\\" {
                            persevere = true
                        } else {
                            abort = true
                        }
                    case "[":
                        if mathBlockStart == "\\\\" {
                            done = true
                        } else {
                            abort = true
                        }
                    default:
                        abort = true
                    }
                    if persevere {
                        mathBlockStart.append(char)
                        mdin.setIndex(.startMath, to: .next)
                        mdin.setIndex(.endMath, to: .next)
                        continue
                    } else if done {
                        mathBlockStart.append(char)
                        mdin.setIndex(.startMath, to: .next)
                        mdin.setIndex(.endMath, to: .next)
                        phase = .text
                        continue
                    } else if abort {
                        mathBlockStart = ""
                        phase = .text
                        nextLine.textFound = true
                        mdin.setIndex(.startText, to: .startMathDelims)
                    }
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
                            } else if mathBlock {
                                continue
                            } else {
                                indentToCode = true
                                mdin.setIndex(.startText, to: .next)
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
                        if nextLine.hashCount == 1 {
                            mdin.setIndex(.startHash, to: .last)
                        }
                        continue
                    } else if char == "-" || char == "+" || char == "*" {
                        leadingBullet = true
                        mdin.setIndex(.startBullet, to: .last)
                        continue
                    } else if char == ":" {
                        leadingColon = true
                        mdin.setIndex(.startColon, to: .last)
                        continue
                    } else if char == "|" {
                        nextLine.leadingPipe = true
                        nextLine.pipeCount = 1
                        nextLine.onlyTableDelimChars = true
                        phase = .text
                    } else if char.isNumber {
                        if following &&
                            (!followingType.isNumberedItem) {
                            phase = .text
                        } else {
                            leadingNumber = true
                            mdin.setIndex(.startNumber, to: .last)
                            continue
                        }
                    } else if char == "[" && nextLine.indentLevels < 1 {
                        linkLabelPhase = .leftBracket
                        refLink = RefLink()
                        footnote = MkdownFootnote()
                        citation = MkdownCitation()
                        phase = .text
                    } else if options.mathJax && (char == "$" || char == "\\") {
                        mathBlockStart.append(char)
                        mdin.setIndex(.startMathDelims, to: .last)
                        // if mathBlockValidStart && nextLine.indentLevels == 0 {
                        //     withinFootnote = false
                        //     withinCitation = false
                        // }
                        continue
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
                    mdin.setIndex(.startText, to: .last)
                }
                if nextLine.type == .unorderedItem && !nextLine.checkBox.isEmpty {
                    if nextLine.checkBox.count == 3 {
                        // it's a done deal
                    } else if char == "[" && nextLine.checkBox.count == 1 {
                        // Just skip it
                    } else if char.lowercased() == "x" && nextLine.checkBox.count == 1 {
                        nextLine.checkBox.append("x")
                    } else if char.isWhitespace && nextLine.checkBox.count == 1 {
                        nextLine.checkBox.append(" ")
                    } else if char.isWhitespace && nextLine.checkBox.count == 2 {
                        // just ignore extra white space
                    } else if char == "]" && nextLine.checkBox.count == 1 {
                        nextLine.checkBox.append(" ]")
                    } else if char == "]" && nextLine.checkBox.count == 2 {
                        nextLine.checkBox.append(char)
                    } else {
                        nextLine.checkBox = ""
                    }
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
                    mdin.setIndex(.endText, to: .next)
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
             
            // And now let's look for the possible end of a math line.
            if options.mathJax && (mathBlockValidStart || mathBlock) {
                if char.isWhitespace {
                    mathLineEndTrailingWhiteSpace = true
                } else {
                    if mathLineEndTrailingWhiteSpace {
                        mathBlockEnd = ""
                        mathLineEndTrailingWhiteSpace = false
                        mdin.setIndex(.endMath, to: .last)
                    }
                    mathBlockEnd.append(char)
                    if mathBlockEnd.count > 3 {
                        mathBlockEnd.remove(at: mathBlockEnd.startIndex)
                        mdin.indexAfter(.endMath)
                    }
                    if mathBlockEnd.count > 2 && mathBlockEnd.hasSuffix("$$") {
                        mathBlockEnd.remove(at: mathBlockEnd.startIndex)
                        mdin.indexAfter(.endMath)
                    }
                }
            }
            
        } // End of processing each character.
        finishLine()
    } // end of func
    
    /// Add new included text if found, and remove old included text when finished with it.
    func pushAndPopIncludes() {

        if textToInclude != nil {
            mdin.push(textToInclude!)
            textToInclude = nil
        } else {
            mdin.popIfEnded()
        }
    }
    
    /// Prepare for a new Markdown line.
    func beginLine() {
        textToInclude = nil
        nextLine = MkdownLine()
        lineIndex = -1
        mdin.setIndex(.startText, to: .next)
        mdin.setIndex(.startLine, to: .next)
        mdin.setIndex(.endLine, to: .next)
        mdin.setIndex(.endText, to: .next)
        phase = .leadingPunctuation
        spaceCount = 0
        charFollowingHashMarks = nil
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
        mdin.setIndex(.startNumber, to: .next)
        mdin.setIndex(.startBullet, to: .next)
        mdin.setIndex(.startColon, to: .next)
        mdin.setIndex(.startHash, to: .next)
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
        mathBlockStart = ""
        mathBlockEnd = ""
        mathLineEndTrailingWhiteSpace = false
        mdin.setIndex(.startMath, to: .next)
        mdin.setIndex(.endMath, to: .next)

    }
    
    /// Wrap up initial examination of the line and figure out what to do with it.
    func finishLine() {
        
        counts.lines += 1
               
        // Capture the entire line for later processing.
        nextLine.line = mdin.getLine()
        
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
        } else if mathBlock {
            let endOfMath = checkForMathClosing()
            nextLine.makeMath(start: false, finish: endOfMath)
            if endOfMath {
                mdin.setIndex(.endText, to: .endMath)
                mathBlock = false
            }
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
        } else if nextLine.hashCount >= 1 && nextLine.hashCount <= 6 && nextLine.textFound && charFollowingHashMarks != nil &&
                    (nextLine.hashCount > 1 ||
                        charFollowingHashMarks!.isWhitespace ||
                        (!charFollowingHashMarks!.isNumber && !options.inlineHashtags)) {
            nextLine.makeHeading(level: nextLine.hashCount, headingNumbers: &headingNumbers)
        } else if nextLine.hashCount > 0 {
            mdin.setIndex(.startText, to: .startLine)
            nextLine.makeOrdinary()
        } else if nextLine.leadingBulletAndSpace {
            if following && followingType != .unorderedItem {
                mdin.setIndex(.startText, to: .startLine)
                nextLine.leadingBulletAndSpace = false
                nextLine.type = .followOn
            } else {
                nextLine.makeUnordered(previousLine: lastLine,
                                       previousNonBlankLine: lastNonBlankLine)
            }
        } else if options.mathJax && mathBlockValidStart {
            mathBlockStartSaved = mathBlockStart
            mdin.setIndex(.startText, to: .startMath)
            let endOfMath = checkForMathClosing()
            nextLine.makeMath(start: true, finish: endOfMath)
            if endOfMath {
                mdin.setIndex(.endText, to: .endMath)
                mathBlock = false
                mathBlockStartSaved = ""
            } else {
                mathBlock = true
            }
            if nextLine.indentLevels == 0 {
                withinCitation = false
                withinFootnote = false
            }
        } else if tableStarted {
            if (nextLine.type == .ordinaryText || nextLine.type == .followOn) && nextLine.leadingPipe {
                nextLine.makeTableLine(requestedType: .tableData, columnStyles: columnStyles)
            } else {
                tableStarted = false
            }
        } else if nextLine.leadingPipe
                    && nextLine.onlyTableDelimChars
                    && nextLine.pipeCount > 1
                    && nextLine.dashCount >= ((nextLine.pipeCount - 1) * 3)
                    && lastLine.leadingPipe
                    && lastLine.pipeCount >= nextLine.pipeCount
                    && lastLine.type == .ordinaryText {
            checkColumnAlignment()
            lastLine.makeTableLine(requestedType: .tableHeader, columnStyles: columnStyles)
            nextLine.makeTableLine(requestedType: .tableDelims, columnStyles: columnStyles)
            tableStarted = true
        } else {
            let cmdLine = MkdownCommandLine()
            nextLine.commandInfo = cmdLine.checkLine(nextLine.line)
            if nextLine.commandInfo.validCommand {
                exposeMarkdownCommand(nextLine.commandInfo.command)
                nextLine.type = nextLine.commandInfo.lineType
                if nextLine.type == .tableOfContents {
                    tocFound = true
                }
                if nextLine.type == .include {
                    if mkdownContext != nil {
                        textToInclude = mkdownContext!.mkdownInclude(item: nextLine.commandInfo.mods,
                                                                     style: nextLine.commandInfo.includeStyle)
                    }
                }
                if nextLine.type == .metadata {
                    codeFenced = true
                    codeFenceChar = "`"
                    codeFenceRepeatCount = 99
                }
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
            // && !leadingLeftAngleBracketAndSlash
            && goodTag) {
            nextLine.makeHTML()
            if possibleTag != "hr" {
                openHTMLblockTag = possibleTag
                openHTMLblock = true
            }
        }
        if nextLine.type == .html {
            mdin.setIndex(.startText, to: .startLine)
        }
        
        // If the line ends with a backslash, treat this like a line break.
        if nextLine.type != .code && nextLine.endsWithBackSlash {
            mdin.indexBefore(.endText)
            nextLine.trailingSpaceCount = 2
        }
        
        if phase == .leadingPunctuation && leadingNumber && nextLine.type == .blank {
            nextLine.textFound = true
            nextLine.makeOrdinary()
            mdin.setIndex(.startText, to: .startNumber)
            mdin.setIndex(.endText, to: .next)
        }

        // Capture the text portion of the line, if it has any.
        if nextLine.type.hasText {
            let text = mdin.getText()
            if !text.isEmpty {
                nextLine.text = text
            }
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
        
        if nextLine.type == .figure {
            withinFigure = true
        } else if nextLine.type == .endFigure {
            withinFigure = false
        }
        
        if !withinFigure && (nextLine.type == .followOn || nextLine.type == .ordinaryText) {
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
    
    func checkColumnAlignment() {
        columnStyles = []
        var columnIndex = -1
        var dashCount = 0
        var leadingColon = false
        var trailingColon = false
        for char in nextLine.line {
            if char == "|" {
                genColumnStyle(columnIndex: columnIndex,
                               dashCount: dashCount,
                               leadingColon: leadingColon,
                               trailingColon: trailingColon)
                columnIndex += 1
                dashCount = 0
                leadingColon = false
                trailingColon = false
            } else if char == "-" {
                dashCount += 1
            } else if char == ":" {
                if dashCount == 0 {
                    leadingColon = true
                } else {
                    trailingColon = true
                }
            }
        }
        genColumnStyle(columnIndex: columnIndex,
                       dashCount: dashCount,
                       leadingColon: leadingColon,
                       trailingColon: trailingColon)
    }
    
    func genColumnStyle(columnIndex: Int, dashCount: Int, leadingColon: Bool, trailingColon: Bool) {
        guard columnIndex >= 0 else { return }
        guard dashCount >= 3 else { return }
        guard leadingColon || trailingColon else { return }
        while columnStyles.count < columnIndex {
            columnStyles.append("")
        }
        if leadingColon && trailingColon {
            columnStyles.append("text-align:center;")
        } else if leadingColon {
            columnStyles.append("text-align:left;")
        } else {
            columnStyles.append("text-align:right;")
        }
    }
        
    /// See if the current line ends a math block.
    func checkForMathClosing() -> Bool {
        guard options.mathJax else {
            mathBlock = false
            return true
        }
        // guard mathBlock else { return true }
        let closed = (mathBlockStartSaved == "$$" && mathBlockEnd == "$$")
                || (mathBlockStartSaved == "\\\\[" && mathBlockEnd == "\\\\]")
        if closed {
            mdin.setIndex(.endText, to: .endMath)
        }
        return closed
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
                if footnote.label.count > 0 {
                    footnote.text.append(char)
                    linkLabelPhase = .noteStart
                } else if citation.label.count > 0 {
                    citation.text.append(char)
                    linkLabelPhase = .citationStart
                } else if char == "<" {
                    angleBracketsUsed = true
                    linkLabelPhase = .linkStart
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
    
    // -----------------------------------------------------------
    //
    // This is the data shared between Phase 1 and Phase 2.
    //
    // -----------------------------------------------------------
    
    var linkDict: [String:RefLink] = [:]
    var footnotes: [MkdownFootnote] = []
    var citations: [MkdownCitation] = []
    var lines:    [MkdownLine] = []
    var tocFound = false
    
    // -----------------------------------------------------------
    //
    // MARK: Phase 2 - Take the lines and convert them
    //       to HTML output.
    //
    // -----------------------------------------------------------
    
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
    
    public var wikiLinkList = WikiLinkList()
    
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
    
    var outlining: MkdownOutlining = .none
    var outlineMod = 0
    var outlineDepth = 0
    var openDetails: [Bool] = [false, false, false, false, false, false, false]
    var outlineElements = 0
    
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
        var firstHeadingLevelRequested = 0
        var lastHeadingLevelRequested = 999
        for line in lines {
            if line.type == .tableOfContents {
                firstHeadingLevelRequested = line.commandInfo.tocLevelStartInt
                lastHeadingLevelRequested = line.commandInfo.tocLevelEndInt
                tocFound = true
                continue
            }
            if !tocFound {
                continue
            }
            if line.type != .heading {
                continue
            }
            
            if line.headingLevel < firstHeadingLevelRequested {
                continue
            }
            
            if line.headingLevel > lastHeadingLevelRequested {
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
            tocLine.indentLevels = line.headingLevel - firstHeadingLevel
            
            if tocLine.indentLevels > 0 {
                for indentLevel in 1...tocLine.indentLevels {
                    _ = tocLine.continueBlock(previousLine: lastLine,
                                              previousNonBlankLine: lastLine,
                                              forLevel: indentLevel)
                }
            }
            tocLine.makeUnordered(previousLine: lastLine,
                                  previousNonBlankLine: lastLine)
            
            tocLines.append(tocLine)
            lastLine = tocLine
        }
    }
    
    var thisLineIsHTML = false
    var lastLineWasHTML = false
    
    var captionStarted = false
    
    /// Go through the Markdown lines, writing out HTML.
    func writeHTML() {
        writer = Markedup()
        lastQuoteLevel = 0
        outlining = .none
        outlineDepth = 0
        openDetails = [false, false, false, false, false, false, false]
        outlineElements = 0
        openBlocks = MkdownBlockStack()
        checkBoxCount = 0
        
        mainLineIndex = 0
        tocLineIndex = 0
        
        thisLineIsHTML = false
        lastLineWasHTML = false
        
        captionStarted = false
        
        var possibleLine = getNextLine()
        
        while possibleLine != nil {
            
            let line = possibleLine!
            
            thisLineIsHTML = false
            
            if !line.followOn {
                // Close any outstanding blocks that are no longer in effect.
                var startToClose = 0
                while startToClose < openBlocks.count {
                    guard startToClose < line.blocks.count else { break }
                    if openBlocks.blocks[startToClose] != line.blocks.blocks[startToClose] {
                        break
                    }
                    if openBlocks.blocks[startToClose].isParagraph && line.startMathBlock {
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
                              text: line.text,
                              checkBox: line.checkBox)
                    openBlocks.append(blockToOpen)
                    blockToOpenIndex += 1
                }
                
                if listItemIndex > 0 {
                    let listIndex = listItemIndex - 1
                    let listBlock = openBlocks.blocks[listIndex]
                    if listBlock.isListTag && listBlock.listWithParagraphs && outlining.noBullets {
                        let paraBlock = MkdownBlock("p")
                        openBlock(paraBlock.tag,
                                  footnoteItem: false,
                                  citationItem: false,
                                  itemNumber: 0,
                                  text: "",
                                  checkBox: line.checkBox)
                        openBlocks.append(paraBlock)
                    }
                }
            }
            
            // Take appropriate action based on type of line.
            switch line.type {
            case .attachments:
                if mkdownContext != nil {
                    writer.spaceBeforeBlock()
                    writer.writeLine(mkdownContext!.mkdownAttachments())
                }
            case .biblio:
                if mkdownContext != nil {
                    writer.spaceBeforeBlock()
                    writer.writeLine(mkdownContext!.mkdownBibliography())
                }
            case .byline:
                byline(line)
            case .calendar:
                if mkdownContext != nil {
                    writer.spaceBeforeBlock()
                    writer.writeLine(mkdownContext!.mkdownCalendar(mods: line.commandInfo.mods))
                }
            case .figure:
                outputChunks()
                writer.startFigure()
                captionStarted = false
            case .caption:
                outputChunks()
                writer.startFigureCaption()
                captionStarted = true
            case .endFigure:
                outputChunks()
                if captionStarted {
                    writer.finishFigureCaption()
                    captionStarted = false
                }
                writer.finishFigure()
            case .segment:
                outputChunks()
                closeBlocks(from: 0)
                startSegment(line)
            case .endSegment:
                outputChunks()
                closeBlocks(from: 0)
                endSegment()
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
                outputChunks()
                writer.horizontalRule()
            case .html:
                thisLineIsHTML = true
                writeHTMLLine(line)
            case .ordinaryText:
                textToChunks(line)
            case .quoteFrom:
                quoteFrom(line)
            case .unorderedItem:
                if outlining.forBullets {
                    writer.startSummary()
                    chunkAndWrite(line)
                    writer.finishSummary()
                    outlineElements += 1
                } else {
                    textToChunks(line)
                }
            case .orderedItem, .footnoteItem, .citationItem:
                textToChunks(line)
            case .defTerm, .defDefinition:
                textToChunks(line)
            case .followOn:
                textToChunks(line)
            case .tableHeader:
                writer.startTableRow()
                columnStyles = line.columnStyles
                columnIndex = 0
                chunkAndWrite(line)
                writer.finishTableRow()
            case .tableDelims:
                break
            case .tableData:
                writer.startTableRow()
                columnStyles = line.columnStyles
                columnIndex = 0
                chunkAndWrite(line)
                writer.finishTableRow()
            case .index:
                if mkdownContext != nil {
                    writer.writeLine(mkdownContext!.mkdownIndex())
                }
            case .inject:
                injectElement = line.commandInfo.getParmElement()
                injectKlass = line.commandInfo.getParmKlass()
                injectID = line.commandInfo.getParmID()
                injectStyle = line.commandInfo.getParmStyle()
            case .search:
                if mkdownContext != nil {
                    writer.writeLine(mkdownContext!.mkdownSearch(siteURL: line.commandInfo.mods))
                }
            case .sortTable:
                tableNumber += 1
                if mkdownContext != nil {
                    tableID = line.commandInfo.mods
                    if tableID.isEmpty {
                        tableID = "table-\(tableNumber)"
                    }
                    if tableNumber == 1 {
                        writer.writeLine(mkdownContext!.mkdownTableSort())
                    }
                    tableSortable = true
                }
            case .tagsCloud:
                if mkdownContext != nil {
                    writer.writeLine(mkdownContext!.mkdownTagsCloud(mods: line.commandInfo.mods))
                }
            case .tagsOutline:
                if mkdownContext != nil {
                    writer.writeLine(mkdownContext!.mkdownTagsOutline(mods: line.commandInfo.mods))
                }
            case .teasers:
                if mkdownContext != nil {
                    writer.writeLine(mkdownContext!.mkdownTeasers())
                }
            case .tocForCollection:
                if mkdownContext != nil {
                    writer.writeLine(
                        mkdownContext!.mkdownCollectionTOC(
                            levelStart: line.commandInfo.tocLevelStartInt,
                            levelEnd: line.commandInfo.tocLevelEndInt,
                            details: outlining == .bullets))
                }
            case .random:
                if mkdownContext != nil {
                    writer.writeLine(mkdownContext!.mkdownRandomNote(klassNames: line.commandInfo.mods))
                }
            case .math:
                if line.startMathBlock {
                    writer.write("$$")
                }
                if StringUtils.trim(line.text).count > 0 {
                    writer.write(line.text)
                }
                if line.finishMathBlock {
                    writer.write("$$")
                }
                writer.newLine()
            case .outlineBullets:
                if outlineElements == 0 && outlining == .headings {
                    outlining = .headingsPlusBullets
                } else {
                    outlining = .bullets
                }
                outlineDepth = 0
                if let modInt = Int(line.commandInfo.mods) {
                    outlineMod = modInt
                }
            case .outlineHeadings:
                outlining = .headings
                outlineDepth = 0
                outlineElements = 0
                if let modInt = Int(line.commandInfo.mods) {
                    outlineMod = modInt
                }
                openDetails = [false, false, false, false, false, false, false]
            case .sectionHeadings:
                sectionOpen = false
                sectionHeadingLevel = -1
                if line.commandInfo.parms.count > 0 {
                    if let level = Int(line.commandInfo.parms) {
                        if level > 0 && level <= 6 {
                            sectionHeadingLevel = level
                        }
                    }
                }
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
            case .include:
                break
            case .header:
                break
            case .footer:
                break
            case .nav:
                break
            case .metadata:
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
            
            lastLineWasHTML = thisLineIsHTML
            
            possibleLine = getNextLine()
            
        }
        closeBlocks(from: 0)
        
        if outlining.forHeadings {
            closeHeadingDetails(downTo: 1)
        }
        
        if sectionOpen {
            writer.finishSection()
        }
        
        if footnoteLines.count > 0 {
            finishWritingFootnotes()
        }
        if citationLines.count > 0 {
            finishWritingCitations()
        }
    }
    
    func byline(_ line: MkdownLine) {
        
        // Get necessary info or exit
        guard !line.commandInfo.parms.isEmpty else {
            return
        }
        
        // Start the paragraph
        writer.startParagraph(klass: MkdownConstants.bylineClass)
        
        // See what info we have
        let author = line.commandInfo.getParm(atIndex: 0)
        let prefix = line.commandInfo.getParm(atIndex: 1)
        let link = line.commandInfo.getParm(atIndex: 2)
        
        if prefix.isEmpty {
            writer.write("by ")
        } else {
            writer.write(prefix)
            if !prefix.hasSuffix(" ") {
                writer.write(" ")
            }
        }
        
        formatLink(link: link, text: author, citeType: .none, relationship: "author noopener")
        
        // End the paragraph
        writer.finishParagraph()
    }
    
    func quoteFrom(_ line: MkdownLine) {
        
        // Get necessary info or exit
        guard !line.commandInfo.parms.isEmpty else { return }
        
        let quoteFrom = QuoteFrom()
        quoteFrom.formatFrom(writer: writer, str: line.commandInfo.parms)
    }
    
    var segmentStack: [String] = []
    
    func startSegment(_ line: MkdownLine) {
        guard !line.commandInfo.parms.isEmpty else { return }
        
        // See what info we have
        let element = line.commandInfo.getParm(atIndex: 0)
        let klass = line.commandInfo.getParm(atIndex: 1)
        let id = line.commandInfo.getParm(atIndex: 2)
        writer.startSegment(element: element, klass: klass, id: id)
        segmentStack.append(element)
        
    }
    
    func endSegment() {
        guard !segmentStack.isEmpty else { return }
        writer.finishSegment(element: segmentStack.removeLast()) 
    }
    
    func formatLink(link: String, text: String, citeType: CiteType, relationship: String? = nil) {
        guard !text.isEmpty else { return }
        var pre = ""
        var post = ""
        switch citeType {
        case .none:
            break
        case .minor:
            pre = "&ldquo;"
            post = "&rdquo;"
        case .major:
            pre = "<cite>"
            post = "</cite>"
        }
        let textPlus = pre + text + post
        if link.isEmpty {
            writer.write(textPlus)
        } else if link.starts(with: "http://") || link.starts(with: "https://") {
            writer.link(text: textPlus, path: link, title: nil, style: nil, klass: "ext-link", blankTarget: true, relationship: relationship)
        } else {
            writer.link(text: textPlus, path: link, title: nil, style: nil, klass: nil, blankTarget: false, relationship: relationship)
        }
    }
    
    func exposeMarkdownCommand(_ command: String) {
        if let context = mkdownContext {
            context.exposeMarkdownCommand(command)
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
    
    /// Write a line of HTML, converting ntnk.app links when needed.
    /// - Parameter line: The line of HTML to be written.
    func writeHTMLLine(_ line: MkdownLine) {
        
        if lastLineWasHTML {
            writer.ensureNewLine()
        } else {
            writer.ensureBlankLine()
        }
        guard mkdownContext != nil
                && options.wikiLinks.format == .fileName
                && options.wikiLinks.interNoteDomain.count > 1 else {
            writer.writeLine(line.line)
            return
        }
        
        var newLine = ""
        var matchingPhase = 0
        
        let domain = options.wikiLinks.interNoteDomain
        var domainIndex = domain.startIndex
        var precedingStart = line.line.startIndex
        var domainStart = line.line.startIndex
        var domainEnd   = line.line.startIndex
        var idEnd       = line.line.startIndex
        
        var lineIndex = line.line.startIndex
        while lineIndex < line.line.endIndex {
            
            let lineChar = line.line[lineIndex]
            
            switch matchingPhase {
                
            case 0:
                if lineChar == domain[domain.startIndex] {
                    matchingPhase = 1
                    domainStart = lineIndex
                    domainIndex = domain.index(after: domain.startIndex)
                }
                
            case 1:
                if lineChar == domain[domainIndex] {
                    domainIndex = domain.index(after: domainIndex)
                    if domainIndex >= domain.endIndex {
                        domainEnd = line.line.index(after: lineIndex)
                        matchingPhase = 2
                    }
                } else {
                    matchingPhase = 0
                }
                
            case 2:
                if lineChar == "\"" {
                    idEnd = lineIndex
                    let id = String(line.line[domainEnd..<idEnd])
                    let wikiLink = assembleWikiLink(title: id)
                    if !wikiLink.isEmpty {
                        newLine.append(String(line.line[precedingStart..<domainStart]))
                        newLine.append(wikiLink)
                        precedingStart = lineIndex
                    }
                    matchingPhase = 0
                }
                
            default:
                break
                
            }
            
            lineIndex = line.line.index(after: lineIndex)
        }
        
        if newLine.isEmpty {
            writer.writeLine(line.line)
            return
        }
        newLine.append(String(line.line[precedingStart..<line.line.endIndex]))
        writer.writeLine(newLine)
        
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
        let anchorID = genAnchorID(poundPrefix: true,
                                   type: .footnote,
                                   direction: .back,
                                   number: number)
        writer.addHref(anchorID)
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
        let anchorID = genAnchorID(poundPrefix: true,
                                   type: .citation,
                                   direction: .back,
                                   number: number)
        writer.addHref(anchorID)
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
            if nextCitation.number > 0 {
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
    func openBlock(_ tag: String,
                   footnoteItem: Bool,
                   citationItem: Bool,
                   itemNumber: Int,
                   text: String,
                   checkBox: String) {
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
            startHeading(level: 1, text: text)
        case "h2":
            startHeading(level: 2, text: text)
        case "h3":
            startHeading(level: 3, text: text)
        case "h4":
            startHeading(level: 4, text: text)
        case "h5":
            startHeading(level: 5, text: text)
        case "h6":
            startHeading(level: 6, text: text)
        case "li":
            if footnoteItem {
                writer.openTag("li")
                let anchorID = genAnchorID(poundPrefix: false,
                                     type: .footnote,
                                     direction: .to,
                                     number: itemNumber)
                writer.addID(anchorID)
                writer.closeTag()
            } else if citationItem {
                writer.openTag("li")
                let anchorID = genAnchorID(poundPrefix: false, type: .citation, direction: .to, number: itemNumber)
                writer.addID(anchorID)
                writer.closeTag()
            } else {
                if checkBox.count == 3 {
                    writer.startListItem(klass: "checklist-item")
                } else {
                    writer.startListItem()
                }
                if outlining.forBullets {
                    if outlineMod > outlineDepth {
                        writer.startDetails(klass: "list-item-\(outlineDepth)-details", openParm: "true")
                    } else {
                        writer.startDetails(klass: "list-item-\(outlineDepth)-details")
                    }
                }
            }
        case "ol":
            writer.startOrderedList(klass: nil)
        case "p":
            if injectElement == "p" {
                writer.startParagraph(klass: injectKlass, id: injectID, style: injectStyle)
                injectElement = ""
                injectKlass = ""
                injectElement = ""
                injectStyle = ""
            } else {
                writer.startParagraph()
            }
        case "pre":
            writer.startPreformatted()
        case "table":
            writer.startTable(id: tableID)
        case "ul":
            if injectElement == "ul" {
                writer.startUnorderedList(klass: injectKlass, id: injectID, style: injectStyle)
                injectElement = ""
                injectKlass = ""
                injectElement = ""
                injectStyle = ""
            } else if outlining.forBullets {
                outlineDepth += 1
                writer.startUnorderedList(klass: "outline-list")
            } else if checkBox.count == 3 {
                writer.startUnorderedList(klass: "checklist")
            } else {
                writer.startUnorderedList()
            }
        default:
            print("Don't know how to open tag of \(tag)")
        }
        chunks = []
    }
    
    func startHeading(level: Int, text: String) {
        if sectionHeadingLevel == -1 {
            sectionHeadingLevel = level
        }
        let headingID = StringUtils.toCommonFileName(text)
        if level == sectionHeadingLevel {
            if sectionOpen {
                writer.finishSection()
            }
            writer.startSection(id: "section-for-\(headingID)")
            sectionOpen = true
        }
        if outlining.forHeadings {
            closeHeadingDetails(downTo: level)
            if outlining.forHeadings {
                outlineDepth += 1
                if outlineMod > outlineDepth {
                    writer.startDetails(klass: "heading-\(level)-details", openParm: "true")
                } else {
                    writer.startDetails(klass: "heading-\(level)-details")
                }
                openDetails[level] = true
                writer.startSummary(id: StringUtils.toCommonFileName(text), klass: "heading-\(level)-summary")
                outlineElements += 1
            }
        } else {
            writer.startHeading(level: level, id: headingID)
        }
    }
    
    func closeHeadingDetails(downTo: Int) {
        var ix = 6
        while ix >= downTo {
            if openDetails[ix] {
                writer.finishDetails()
                openDetails[ix] = false
                outlineDepth -= 1
                if outlining == .bullets && outlineDepth < 1 {
                    outlining = .none
                }
            }
            ix -= 1
        }
    }
    
    func closeBlocks(from startToClose: Int) {
        var blockToClose = openBlocks.count - 1
        while blockToClose >= startToClose {
            let block = openBlocks.blocks[blockToClose]
            closeBlock(tag: block.tag,
                       footnoteItem: block.footnoteItem,
                       citationItem: block.citationItem,
                       itemNumber: block.itemNumber)
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
            finishHeading(level: 1)
        case "h2":
            finishHeading(level: 2)
        case "h3":
            finishHeading(level: 3)
        case "h4":
            finishHeading(level: 4)
        case "h5":
            finishHeading(level: 5)
        case "h6":
            finishHeading(level: 6)
        case "li":
            if outlining.forBullets {
                writer.finishDetails()
            }
            writer.finishListItem()
        case "ol":
            writer.finishOrderedList()
        case "p":
            writer.finishParagraph()
        case "pre":
            writer.finishPreformatted()
        case "table":
            writer.finishTable()
            tableSortable = false
            tableID = ""
        case "ul":
            if outlining.forBullets {
                outlineDepth -= 1
                if outlineDepth < 1 {
                    outlining = .none
                }
            }
            writer.finishUnorderedList()
        default:
            print("Don't know how to close tag of \(tag)")
        }
    }
    
    func finishHeading(level: Int) {
        if outlining.forHeadings {
            writer.finishSummary()
        } else {
            writer.finishHeading(level: level)
        }
    }
    
    /// Divide a line up into chunks, then write them out.
    func chunkAndWrite(_ line: MkdownLine) {
        textToChunks(line)
        outputChunks()
    }
    
    // -----------------------------------------------------------
    //
    // MARK: Section 2.a - Go through the text in a block and
    // break it up into chunks.
    //
    // -----------------------------------------------------------
    
    /// Divide another line of Markdown into chunks.
    func textToChunks(_ line: MkdownLine) {
        
        nextChunk = MkdownChunk(line: line)
        backslashed = false
        var lastChar: Character = " "
        if line.type == .followOn {
            nextChunk.startsWithSpace = true
            nextChunk.endsWithSpace = true
            // appendToNextChunk(str: " ", lastChar: " ", line: line)
            appendToNextChunk(str: "", lastChar: " ", line: line)
        }
        for char in line.text {
            if backslashed {
                if !validEscape(char: char) {
                    backslashed = false
                    if chunks.count > 0 {
                        let priorChunk = chunks[chunks.count - 1]
                        if priorChunk.type == .backSlash {
                            priorChunk.type = .plaintext
                        }
                    }
                }
            }
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
                case ";":
                    addCharAsChunk(char: char, type: .semicolon, lastChar: lastChar, line: line)
                case "!":
                    addCharAsChunk(char: char, type: .exclamationMark, lastChar: lastChar, line: line)
                case "~":
                    addCharAsChunk(char: char, type: .tilde, lastChar: lastChar, line: line)
                case "=":
                    addCharAsChunk(char: char, type: .equalSign, lastChar: lastChar, line: line)
                case "|":
                    if line.type == .tableHeader {
                        addCharAsChunk(char: char, type: .tableHeaderPipe, lastChar: lastChar, line: line)
                    } else if line.type == .tableData {
                        addCharAsChunk(char: char, type: .tableDataPipe, lastChar: lastChar, line: line)
                    } else {
                        addCharAsChunk(char: char, type: .plainPipe, lastChar: lastChar, line: line)
                        // appendToNextChunk(char: char, lastChar: lastChar, line: line)
                        // nextChunk.textCount += 1
                        // anotherWord = true
                    }
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
    
    func validEscape(char: Character) -> Bool {
        switch char {
        case "\\", "`", "*", "_", "{", "}", "[", "]", "(", ")":
            return true
        case "#", "+", "-", ".", "!":
            return true
        case "|":
            return true
        default:
            return false
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
            case .tilde:
                if chunk.lineType == .code { break }
                if withinCodeSpan { break }
                if withinMathSpan { break }
                if withinTag { break }
                scanForStrikethrough(forChunkAt: index)
                if chunk.type == .tilde {
                    scanForSubscript(forChunkAt: index)
                }
            case .equalSign:
                if chunk.lineType == .code { break }
                if withinCodeSpan { break }
                if withinMathSpan { break }
                if withinTag { break }
                scanForHighlight(forChunkAt: index)
            case .caret:
                if chunk.lineType == .code { break }
                if withinCodeSpan { break }
                if withinMathSpan { break }
                if withinTag { break }
                scanForSuperscript(forChunkAt: index)
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
                scanForEntityReferenceClosure(forChunkAt: index)
            case .leftSquareBracket:
                if chunk.lineType == .code { break }
                if withinCodeSpan { break }
                if withinMathSpan { break }
                if withinTag { break }
                scanForCheckBox(forChunkAt: index)
                if chunk.type == .leftSquareBracket {
                    scanForLinkElements(forChunkAt: index)
                }
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
                if index > 0 {
                    let priorChunk = chunks[index - 1]
                    if priorChunk.endsWithSpace {
                        // might be start of math
                    } else {
                        let priorChar = priorChunk.text.last
                        if priorChar == nil {
                            // might be start of math
                        } else if priorChar!.isPunctuation {
                            // might be start of math
                        } else {
                            break
                        }
                    }
                }
                scanForDollarSigns(forChunkAt: index)
                if chunk.type == .startMath {
                    withinMathSpan = true
                }
            case .poundSign:
                if !options.inlineHashtags { break }
                if chunk.lineType == .code { break }
                if withinCodeSpan { break }
                if withinMathSpan { break }
                if withinTag { break }
                if nextIndex >= chunks.count { break }
                if chunk.endsWithSpace { break }
                if chunks[nextIndex].startsWithSpace { break }
                _ = scanForHashtag(forChunkAt: index)
            case .backSlash:
                if !options.mathJax { break }
                if chunk.lineType == .code { break }
                if withinCodeSpan { break }
                if withinTag { break }
                scanForSlashParens(forChunkAt: index)
                if chunk.type == .startMath {
                    withinMathSpan = true
                }
            case .tableHeaderPipe, .tableDataPipe, .tableHeaderPipeExtra, .tableDataPipeExtra:
                if chunk.lineType == .code { break }
                if withinCodeSpan { break }
                if withinMathSpan { break }
                if withinTag { break }
                scanForTableElements(forChunkAt: index)
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
    
    func scanForEntityReferenceClosure(forChunkAt: Int) {
        let firstChunk = chunks[forChunkAt]
        var ref = ""
        
        var next = forChunkAt + 1
        while next < chunks.count {
            nextChunk = chunks[next]
            switch nextChunk.type {
            case .semicolon:
                if ref.count > 1 && ref.count <= 16 {
                    firstChunk.type = .entityStart
                    nextChunk.type = .entityEnd
                }
                return
            case .plaintext:
                if nextChunk.endsWithSpace || nextChunk.endsWithSpace {
                    return
                }
                ref.append(nextChunk.text)
                if ref.count > 16 {
                    return
                }
            case .poundSign:
                if ref.isEmpty {
                    ref.append(nextChunk.text)
                } else {
                    return
                }
            default:
                return
            }
            next += 1
        }
    }
    
    /// When a  .tableHeaderPipe or .tableDataPipe is encountered,
    /// assign a more granular pipe type.
    func scanForTableElements(forChunkAt: Int) {

        let firstChunk = chunks[forChunkAt]
        
        // Make colspan adjustments, if any.
        var next = forChunkAt + 1
        if next < chunks.count && !firstChunk.type.extraPipe {
            var priorNextChunk: MkdownChunk? = nil
            var endingPipesFound = false
            var endingPipesPassed = false
            while next < chunks.count && !endingPipesPassed {
                nextChunk = chunks[next]
                if nextChunk.type.tablePipePending {
                    endingPipesFound = true
                }
                if nextChunk.type.tablePipePending {
                    if priorNextChunk != nil && priorNextChunk!.type.tablePipePrelim {
                        firstChunk.columnsToSpan += 1
                        nextChunk.type = nextChunk.type.makeExtra
                    }
                } else {
                    if endingPipesFound {
                        endingPipesPassed = true
                    }
                }
                priorNextChunk = nextChunk
                next += 1
            }
        }
        
        // Handle the starting pipe for the line.
        if forChunkAt == 0 {
            firstChunk.type = firstChunk.type.makeFinal(position: .start)
            return
        }
        
        guard !firstChunk.type.extraPipe else { return }
        
        var moreToTheRow = false
        
        next = forChunkAt + 1
        
        while !moreToTheRow && next < chunks.count {
            nextChunk = chunks[next]
            if nextChunk.type.extraPipe {
                // ignore these
            } else if nextChunk.type != .plaintext {
                moreToTheRow = true
            } else if !StringUtils.trim(nextChunk.text).isEmpty {
                moreToTheRow = true
            }
            next += 1
        }
        
        if moreToTheRow {
            firstChunk.type = firstChunk.type.makeFinal(position: .middle)
        } else {
            firstChunk.type = firstChunk.type.makeFinal(position: .finish)
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
                    if followingChunk.startsWithSpace {
                        matched = true
                    } else if followingChunk.type != .plaintext {
                        matched = true
                    } else {
                        let followingChar = followingChunk.text.first
                        if followingChar == nil {
                            matched = true
                        } else if followingChar!.isPunctuation {
                            matched = true
                        }
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
    
    // Look for backslash parenthesis combinations that indicate inline math.
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
        
        if precedingCharIsLetter(forChunkAt: forChunkAt) {
            firstChunk.type = .apostrophe
            return
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
    
    func scanForHashtag(forChunkAt: Int) -> Bool {

        let firstChunk = chunks[forChunkAt]
        let next = forChunkAt + 1
        guard next < chunks.count else { return false }
        let nextChunk = chunks[next]
        var allDigits = true
        var hashTag = ""
        
        var hashtagLength = 0
        var splitChunk = false
        for char in nextChunk.text {
            if hashTag.isEmpty && StringUtils.isDigit(char) {
                break
            } else if char.isWhitespace {
                splitChunk = true
                break
            } else if char == "-" || char == "_" {
                hashTag.append(char)
                hashtagLength += 1
            } else if char.isPunctuation {
                splitChunk = true
                break
            } else {
                hashTag.append(char)
                hashtagLength += 1
            }
            if StringUtils.isAlpha(char) {
                allDigits = false
            }
        }
        if allDigits { return false }
        if hashTag.isEmpty { return false }
        if mkdownContext != nil {
            firstChunk.hashtagLink = mkdownContext!.addHashTag(hashTag)
        }
        let insertPosition = next + 1
        firstChunk.type = .hashtag
        let hashtagEnd = MkdownChunk()
        hashtagEnd.type = .hashtagEnd
        if splitChunk {
            let afterChunk = MkdownChunk()
            let afterLength = nextChunk.text.count - hashtagLength
            afterChunk.text = String(nextChunk.text.suffix(afterLength))
            nextChunk.text = hashTag
            if insertPosition >= chunks.count {
                chunks.append(afterChunk)
            } else {
                chunks.insert(afterChunk, at: insertPosition)
            }
        }
        if insertPosition >= chunks.count {
            chunks.append(hashtagEnd)
        } else {
            chunks.insert(hashtagEnd, at: insertPosition)
        }
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
    
    /// See if this tilde character marks the start of a subscript.
    /// - Parameter forChunkAt: Index to the chunk containing the first tilde.
    func scanForSubscript(forChunkAt: Int) {
        start = forChunkAt
        startChunk = chunks[start]
        var next = start + 1
        var looking = true
        var content = false
        while next < chunks.count && looking {
            let nextChunk = chunks[next]
            if nextChunk.type == startChunk.type {
                if content {
                    startChunk.type = .startSubscript
                    nextChunk.type = .endSubscript
                }
                looking = false
            } else {
                content = true
                if nextChunk.startsWithSpace || nextChunk.endsWithSpace || nextChunk.text.contains(" ") {
                    looking = false
                }
            }
            next += 1
        }
    }
    
    /// See if this caret character marks the start of a superscript.
    /// - Parameter forChunkAt: Index to the chunk containing the first caret.
    func scanForSuperscript(forChunkAt: Int) {
        start = forChunkAt
        startChunk = chunks[start]
        var next = start + 1
        var looking = true
        var content = false
        while next < chunks.count && looking {
            let nextChunk = chunks[next]
            if nextChunk.type == startChunk.type {
                if content {
                    startChunk.type = .startSuperscript
                    nextChunk.type = .endSuperscript
                }
                looking = false
            } else {
                content = true
                if nextChunk.startsWithSpace || nextChunk.endsWithSpace || nextChunk.text.contains(" ") {
                    looking = false
                }
            }
            next += 1
        }
    }
    
    /// Scan for closing tildes to form a strikethrough.
    func scanForStrikethrough(forChunkAt: Int) {
        start = forChunkAt
        startChunk = chunks[start]
        var next = start + 1
        consecutiveStartCount = 1
        leftToClose = 1
        consecutiveCloseCount = 0
        matchStart = -1
        var struckCount = 0
        while leftToClose > 0 && next < chunks.count {
            let nextChunk = chunks[next]
            if nextChunk.type == startChunk.type {
                if consecutiveStartCount == 1 && next == (start + 1) {
                    consecutiveStartCount = 2
                    leftToClose = 2
                } else if consecutiveStartCount == 2 && struckCount > 0 && consecutiveCloseCount == 0 {
                    consecutiveCloseCount = 1
                    leftToClose = 1
                    matchStart = next
                } else if consecutiveStartCount == 2
                            && struckCount > 0
                            && consecutiveCloseCount == 1
                            && next == (matchStart + 1) {
                    consecutiveCloseCount = 2
                    leftToClose = 0
                    processStrikethroughClosure()
                }
            } else if consecutiveStartCount == 2 && consecutiveCloseCount == 0 {
                struckCount += 1
            } else if consecutiveStartCount == 2 && consecutiveCloseCount == 1 {
                struckCount += 2
                consecutiveCloseCount = 0
                leftToClose = 2
            } else {
                leftToClose = 0
            }
            next += 1
        }
    }
    
    /// Let's close things up.
    func processStrikethroughClosure() {
        startChunk.type = .startStrikethrough1
        chunks[start + 1].type = .startStrikethrough2
        chunks[matchStart].type = .endStrikethrough1
        chunks[matchStart + 1].type = .endStrikethrough2
    }
    
    /// Scan for closing equal signs to form a highlight. .
    func scanForHighlight(forChunkAt: Int) {
        start = forChunkAt
        startChunk = chunks[start]
        var next = start + 1
        consecutiveStartCount = 1
        leftToClose = 1
        consecutiveCloseCount = 0
        matchStart = -1
        var highlightCount = 0
        while leftToClose > 0 && next < chunks.count {
            let nextChunk = chunks[next]
            if nextChunk.type == startChunk.type {
                if consecutiveStartCount == 1 && next == (start + 1) {
                    consecutiveStartCount = 2
                    leftToClose = 2
                } else if consecutiveStartCount == 2 && highlightCount > 0 && consecutiveCloseCount == 0 {
                    consecutiveCloseCount = 1
                    leftToClose = 1
                    matchStart = next
                } else if consecutiveStartCount == 2
                            && highlightCount > 0
                            && consecutiveCloseCount == 1
                            && next == (matchStart + 1) {
                    consecutiveCloseCount = 2
                    leftToClose = 0
                    processHighlightClosure()
                }
            } else if consecutiveStartCount == 2 && consecutiveCloseCount == 0 {
                highlightCount += 1
            } else if consecutiveStartCount == 2 && consecutiveCloseCount == 1 {
                highlightCount += 2
                consecutiveCloseCount = 0
                leftToClose = 2
            } else {
                leftToClose = 0
            }
            next += 1
        }
    }
    
    /// Let's close things up.
    func processHighlightClosure() {
        startChunk.type = .startHighlight1
        chunks[start + 1].type = .startHighlight2
        chunks[matchStart].type = .endHighlight1
        chunks[matchStart + 1].type = .endHighlight2
    }
    
    /// If we have an asterisk or an underline, look for the closing symbols to end the emphasis span.
    func scanForEmphasisClosure(forChunkAt: Int) {
        
        start = forChunkAt
        startChunk = chunks[start]
        
        // Leave mid-word underlines as-is
        if startChunk.type == .underline && precedingCharIsLetter(forChunkAt: forChunkAt) {
            return
        }
        
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
    
    func precedingCharIsLetter(forChunkAt: Int) -> Bool {
        
        guard forChunkAt > 0 else { return false }
        let priorChunk = chunks[forChunkAt - 1]
        guard priorChunk.type == .plaintext else { return false }
        let priorChar = priorChunk.text.last
        return (priorChar != nil && priorChar!.isLetter)
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
        var titlePipe: MkdownChunk?
        var rightBracket1: MkdownChunk?
        var rightBracket2: MkdownChunk?
        var closingTextBracketIndex = -1
        var leftLabelBracket: MkdownChunk?
        var leftLabelBracketIndex = -1
        var rightLabelBracket: MkdownChunk?
        var leftParen: MkdownChunk?
        var leftQuote: MkdownChunk?
        var inlinePoundSign: MkdownChunk?
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
                } else {
                    inlinePoundSign = chunk
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
            case .plainPipe:
                if doubleBrackets && rightBracket1 == nil {
                    titlePipe = chunk
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
        
        if inlinePoundSign != nil {
            inlinePoundSign!.type = .onlyAPoundSign
        }
        
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
            if titlePipe != nil {
                titlePipe!.type = .startWikiLinkTitle
            }
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
    
    /// If we have a left square bracket, scan for other punctuation related to a link.
    func scanForCheckBox(forChunkAt: Int) {
   
        let leftBracket = chunks[forChunkAt]
        guard leftBracket.type == .leftSquareBracket else { return }
        guard forChunkAt == 0 else { return }
        var onOrOff: MkdownChunk?
        var rightBracket: MkdownChunk?
        var looking = true
        var index = forChunkAt + 1
        while looking && index < chunks.count {
            let chunk = chunks[index]
            switch chunk.type {
            case .rightSquareBracket:
                rightBracket = chunk
                looking = false
            case .plaintext:
                if chunk.text.lowercased() == "x" || chunk.text == " " {
                    onOrOff = chunk
                } else {
                    looking = false
                }
            default:
                looking = false
            }
            index += 1
        }
        
        guard !looking else { return }
        guard rightBracket != nil else { return }
        
        leftBracket.type = .startCheckBox
        if onOrOff == nil {
            rightBracket!.type = .endCheckBoxUnchecked
        } else if onOrOff!.text.lowercased() == "x" {
            rightBracket!.type = .endCheckBoxChecked
            onOrOff!.type = .checkBoxContent
        } else {
            rightBracket!.type = .endCheckBoxUnchecked
            onOrOff!.type = .checkBoxContent
        }
    }
    
    // -----------------------------------------------------------
    //
    // MARK: Section 2.c - Send the chunks to the writer.
    //
    // -----------------------------------------------------------
    
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
        withinMathSpan = false
        backslashed = false
        footnote = MkdownFootnote()
        citation = MkdownCitation()
        var chunkIndex = 0
        for chunkToWrite in chunksToWrite {
            if chunkToWrite.type == .startCode {
                withinCodeSpan = true
            } else if chunkToWrite.type == .endCode {
                withinCodeSpan = false
            } else if chunkToWrite.type == .startMath {
                withinMathSpan = true
            } else if chunkToWrite.type == .endMath {
                withinMathSpan = false
            }
            write(chunk: chunkToWrite, chunkIndex: chunkIndex, maxIndex: chunksToWrite.count - 1)
            chunkIndex += 1
        }
    }
    
    /// Write out a single chunk.
    func write(chunk: MkdownChunk, chunkIndex: Int, maxIndex: Int) {
        
        // If we're in the middle of a link, then capture the text for its
        // various elements instead of writing anything out in the normal
        // linear flow.
        
        if linkElementDiverter != .na {
            switch linkElementDiverter {
            case .text:
                if chunk.type == .endLinkText || chunk.type == .endWikiLink1 {
                    linkElementDiverter = .na
                } else if chunk.type == .startWikiLinkTitle {
                    linkElementDiverter = .title
                    linkTextChunks = []
                    return
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
                if chunk.type == .endTitle || chunk.type == .endLink || chunk.type == .endWikiLink1 {
                    linkElementDiverter = .na
                } else if doubleBrackets {
                    linkTextChunks.append(chunk)
                    return
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
                    if chunk.type == .atSign && autoLinkSep == " " {
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
            case .entityStart:
                writer.write("&")
            case .semicolon:
                writer.write(";")
            case .entityEnd:
                writer.write(";")
            case .apostrophe:
                if options.curlyApostrophes {
                    writer.writeEndingSingleQuote()
                } else {
                    writer.writeApostrophe()
                }
            case .backSlash:
                if withinCodeSpan || withinMathSpan {
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
            case .startStrikethrough1:
                writer.startStrikethrough()
            case .startStrikethrough2:
                break
            case .endStrikethrough1:
                break
            case .endStrikethrough2:
                writer.finishStrikethrough()
            case .startHighlight1:
                writer.startMark()
            case .startHighlight2:
                break
            case .endHighlight1:
                break
            case .endHighlight2:
                writer.finishMark()
            case .startSubscript:
                writer.startSubscript()
            case .endSubscript:
                writer.finishSubscript()
            case .startSuperscript:
                writer.startSuperscript()
            case .endSuperscript:
                writer.finishSuperscript()
            case .startFootnoteLabel1:
                break
            case .startFootnoteLabel2:
                footnote = MkdownFootnote()
                footnoteText = true
            case .endFootnoteLabel:
                footnote.inputLine = chunk.text
                let assignedNumber = addFootnote()
                writer.openTag("a")
                var anchorID = genAnchorID(poundPrefix: true, type: .footnote, direction: .to, number: assignedNumber)
                writer.addHref(anchorID)
                anchorID = genAnchorID(poundPrefix: false, type: .footnote, direction: .back, number: assignedNumber)
                writer.addID(anchorID)
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
                    var anchorID = genAnchorID(poundPrefix: true, type: .citation, direction: .to, number: assignedNumber)
                    writer.addHref(anchorID)
                    anchorID = genAnchorID(poundPrefix: false, type: .citation, direction: .back, number: assignedNumber)
                    writer.addID(anchorID)
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
                linkTitle = ""
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
                if withinCodeSpan {
                    writer.write("...")
                } else {
                    writer.ellipsis()
                }
            case .endash:
                if withinCodeSpan {
                    writer.write("--")
                } else {
                    writer.writeEnDash()
                }
            case .emdash:
                if withinCodeSpan {
                    writer.write("---")
                } else {
                    writer.writeEmDash()
                }
            case .singleCurlyQuoteOpen:
                writer.leftSingleQuote()
            case .singleCurlyQuoteClose:
                writer.rightSingleQuote()
            case .doubleCurlyQuoteOpen:
                writer.leftDoubleQuote()
            case .doubleCurlyQuoteClose:
                writer.rightDoubleQuote()
                
            // Deal with table pipes
            case .headerColumnStart:
                var onclick = ""
                if tableSortable {
                    onclick = "sortTable(\'\(tableID)\',\(columnIndex))"
                }
                writer.startTableHeader(onclick: onclick, style: getColumnStyle(columnIndex: columnIndex), colspan: chunk.columnsToSpan)
                columnsSpanned = chunk.columnsToSpan
            case .headerColumnFinish:
                writer.finishTableHeader()
                columnIndex += columnsSpanned
            case .headerColumnFinishAndStart:
                writer.finishTableHeader()
                columnIndex += columnsSpanned
                var onclick = ""
                if tableSortable {
                    onclick = "sortTable(\'\(tableID)\',\(columnIndex))"
                }
                writer.startTableHeader(onclick: onclick, style: getColumnStyle(columnIndex: columnIndex), colspan: chunk.columnsToSpan)
                columnsSpanned = chunk.columnsToSpan
            case .dataColumnStart:
                writer.startTableData(style: getColumnStyle(columnIndex: columnIndex), colspan: chunk.columnsToSpan)
                columnsSpanned = chunk.columnsToSpan
            case .dataColumnFinish:
                writer.finishTableData()
                columnIndex += columnsSpanned
            case .dataColumnFinishAndStart:
                writer.finishTableData()
                columnIndex += columnsSpanned
                writer.startTableData(style: getColumnStyle(columnIndex: columnIndex), colspan: chunk.columnsToSpan)
                columnsSpanned = chunk.columnsToSpan
            case .tableDataPipeExtra, .tableHeaderPipeExtra:
                break
            case .startCheckBox:
                break
            case .checkBoxContent:
                break
            case .endCheckBoxChecked:
                genCheckBox(checked: true)
            case .endCheckBoxUnchecked:
                genCheckBox(checked: false)
            case.hashtag:
                writer.startLink(path: chunk.hashtagLink, klass: "hashtag")
                writer.write(chunk.text)
            case .hashtagEnd:
                writer.finishLink()
            default:
                writer.append(chunk.text)
            }
        }
    }
    
    // Check Box Generation variables
    var checkBoxCount = 0
    var checkBoxCountStr: String {
        return String(format: "%03d", checkBoxCount)
    }
    var checkBoxName: String {
        return "ckbox\(checkBoxCountStr)"
    }
    
    /// Check box generation.
    func genCheckBox(checked: Bool) {
        checkBoxCount += 1
        if options.checkBoxMessageHandlerName.isEmpty {
            if checked {
                writer.write("&#9745; ")
            } else {
                writer.write("&#9744; ")
            }
        } else {
            writer.checkbox(id: checkBoxName, name: checkBoxName, checked: checked)
            writer.startScript()
            let js = """
            var _selector = document.querySelector('#\(checkBoxName)');
            _selector.addEventListener('change', function(event) {
                var _target = event.target
                var message = (_target.checked) ? "\(MkdownConstants.checked)" : "\(MkdownConstants.unchecked)";
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(options.checkBoxMessageHandlerName)) {
                    window.webkit.messageHandlers.\(options.checkBoxMessageHandlerName).postMessage({
                        "checkBoxNumber": "\(checkBoxCountStr)",
                        "checkBoxState": message
                    });
                }
            });
            """
            writer.append(js)
            writer.finishScript()
        }
    }
    
    var columnsSpanned = 1
    
    func getColumnStyle(columnIndex: Int) -> String {
        guard columnIndex >= 0 && columnIndex < columnStyles.count else { return "" }
        return columnStyles[columnIndex]
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
            writer.link(text: autoLink, path: autoLink, klass: Markedup.htmlClassExtLink, blankTarget: options.extLinksOpenInNewWindows)
        } else {
            writer.link(text: autoLink, path: "mailto:\(autoLink)", klass: Markedup.htmlClassExtLink)
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
        
        var skipLink = false
        
        // If this is a wiki style link, then format the URL from the text.
        var blankTarget = options.extLinksOpenInNewWindows
        var linkClass = Markedup.htmlClassExtLink
        if doubleBrackets {
            linkURL = assembleWikiLink(title: linkText)
            blankTarget = false
            linkClass = Markedup.htmlClassWikiLink
        }

        // If this is a reference style link, then let's look it up in the dictionary.
        if linkURL.isEmpty {
            if linkLabel.count == 0 {
                linkLabel = linkText.lowercased()
            }
            let refLink = linkDict[linkLabel]
            if refLink == nil {
                skipLink = true
            } else {
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
            var modifiedLink = linkURL
            if options.flattenImageLinks && !linkURL.contains("://") {
                modifiedLink = StringUtils.toCommonFileName(linkURL, leavingSlashes: true)
                if let relPath = options.relativePathToRoot {
                    if !relPath.isEmpty {
                        modifiedLink = relPath + modifiedLink
                    }
                }
            }
            writer.image(alt: linkText, path: modifiedLink, title: linkTitle)
            if mkdownContext != nil {
                mkdownContext!.exposeImageLink(original: linkURL, modified: modifiedLink)
            }
        } else if skipLink {
            writeChunks(chunksToWrite: linkTextChunks)
        } else {
            if !linkURL.starts(with: "https://") && !linkURL.starts(with: "http://") {
                linkClass = Markedup.htmlClassWikiLink
                if blankTarget {
                    blankTarget = false
                }
            }
            writer.startLink(path: linkURL, title: linkTitle, klass: linkClass, blankTarget: blankTarget)
            if doubleBrackets && linkTextChunks.count == 1 && linkTextChunks[0].type == .plaintext {
                let (_, item) = StringUtils.splitPath(linkTextChunks[0].text)
                writer.append(item)
            } else {
                writeChunks(chunksToWrite: linkTextChunks)
            }
            writer.finishLink()
        }
        initLink()
    }
    
    func assembleWikiLink(title: String) -> String {

        let wikiLink = WikiLink()
        wikiLink.setOriginalTarget(title)
        if mkdownContext != nil {
            let lookedUp = mkdownContext!.mkdownWikiLinkLookup(linkText: title)
            if lookedUp == nil {
                wikiLink.targetFound = false
            } else {
                wikiLink.updatedTarget = lookedUp!
                wikiLink.targetFound = true
            }
            wikiLinkList.links.append(wikiLink)
        }
        return options.wikiLinks.assembleWikiLink(target: wikiLink.bestTarget)
    }
    
    func formatWikiLink(_ target: WikiLinkTarget) -> String {
        switch options.wikiLinks.format {
        case .common:
            return target.pathSlashID
        case .fileName:
            return target.pathSlashFilename
        case .mmdID:
            return target.pathSlashFilename
        }
    }
    
    /// Generate an Anchor ID to be used for internal page links.
    /// - Parameters:
    ///   - poundPrefix: Set to true if the result will be used in an href, or false if to be used in an id.
    ///   - type: Citation or Footnote?
    ///   - direction: Is this a link to the footnote/citation, or a link back to the referencing text.
    ///   - number: The number identifying the sequence of the footnote/citation within the note/page.
    /// - Returns: A complete formatted ID that can be used for consistency.
    func genAnchorID(poundPrefix: Bool,
                     type: AnchorIdType,
                     direction: AnchorIdDirection,
                     number: Int) -> String {
        var id = ""
        
        if poundPrefix {
            id.append("#")
        }
        
        switch type {
        case .citation:
            id.append("cn")
        case .footnote:
            id.append("fn")
        }
        
        switch direction {
        case .to:
            break
        case .back:
            id.append("ref")
        }
        id.append(":")
        
        if !options.shortID.isEmpty {
            id.append("\(options.shortID)-")
        }
        
        id.append("\(number)")

        return id
    }
    
    enum LinkElementDiverter {
        case na
        case text
        case label
        case title
        case url
        case autoLink
    }
    
    enum AnchorIdType {
        case citation
        case footnote
    }
    
    enum AnchorIdDirection {
        case to
        case back
    }
    
    enum CiteType {
        case none
        case minor
        case major
    }
    
}
