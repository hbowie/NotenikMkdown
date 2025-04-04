//
//  MkdownLine.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 2/25/20.
//  Copyright © 2020 - 2022 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

/// One line in Markdown syntax.
class MkdownLine {
    
    var line = ""
    
    var type: MkdownLineType = .blank
    
    var withinFootnote = false
    var endOfFootnote = false
    
    var withinCitation = false
    var endOfCitation = false
    
    var blocks = MkdownBlockStack()
    var quoteLevel = 0
    var hashCount = 0
    var headingNumber = 0
    var headingLevel = 0
    
    var indentLevels = 0
    
    var repeatingChar: Character = " "
    var repeatingStart = ""
    var stillRepeating = false
    var repeatCount = 0
    var onlyRepeating = true
    var onlyRepeatingAndSpaces = true
    
    
    var leadingBulletAndSpace = false
    var checkBox = ""
    var validCheckBox: Bool {
        return checkBox.count == 3
    }
    
    var leadingColonAndSpace = false
    
    var leadingPipe = false
    var pipeCount = 0
    var dashCount = 0
    var onlyTableDelimChars = false
    
    var columnStyles: [String] = []
    
    var commandInfo = MkdownCommandInfo()
    
    var tagsIncludeUntagged = true
    
    var headingUnderlining: Bool {
        return (onlyRepeating && repeatCount >= 2 &&
            (repeatingChar == "=" || repeatingChar == "-"))
    }
    
    var horizontalRule: Bool {
        return onlyRepeatingAndSpaces && repeatCount >= 3 &&
            (repeatingChar == "-" || repeatingChar == "*" || repeatingChar == "_")
    }
    
    /// Is this a code fence line?
    /// - Parameters:
    ///   - inProgress: Are we already within a code fence?
    ///   - lastChar: The last character used to indicate a code fence.
    ///   - lastRepeatCount: The number of times the character was repeated.
    /// - Returns: True if this line qualified as a code fence.
    func codeFence(inProgress: Bool, lastChar: Character, lastRepeatCount: Int) -> Bool {
        guard repeatCount >= 3 else { return false }
        guard repeatingStart.count >= 3 else { return false }
        guard repeatingStart.first == "`" || repeatingStart.first == "~" else { return false }
        guard repeatingChar == "`" || repeatingChar == "~" else { return false }
        if inProgress {
            return (onlyRepeating && repeatingChar == lastChar && repeatCount == lastRepeatCount)
        } else {
            return true
        }
    }
    
    var textFound = false
    var text = ""

    var trailingSpaceCount = 0
    var endsWithNewline = false
    var endsWithBackSlash = false
    
    /// Is the line empty?
    var isEmpty: Bool {
        return line.count == 0 && !endsWithNewline
    }
    
    var endsWithLineBreak: Bool {
        guard trailingSpaceCount >= 2 else { return false }
        switch type {
        case .blank: 
            return false
        case .code: 
            return false
        case .tableData, .tableDelims, .tableHeader:
            return false
        default: 
            return true
        }
    }
    
    func makeCode() {
        type = .code
        blocks.append("pre")
        blocks.append("code")
    }
    
    var startMathBlock = false
    var finishMathBlock = false
    
    func makeMath(start: Bool, finish: Bool) {
        type = .math
        addParagraph()
        startMathBlock = start
        finishMathBlock = finish
    }
    
    func makeHeading(level: Int, headingNumbers: inout [Int]) {
        
        var clear = headingNumbers.count - 1
        while clear > level {
            headingNumbers[clear] = 0
            clear -= 1
        }
        
        preserveHeadingNumber(level: level, headingNumbers: &headingNumbers)
        headingNumbers[level] = headingNumber
        
        type = .heading
        headingLevel = level
        if blocks.last.isHeadingTag || blocks.last.isParagraph {
            blocks.removeLast()
        }
        blocks.append("h\(level)")
    }
    
    /// If this line started with ordered item numbering, then take actions to preserve
    /// the number.
    func preserveHeadingNumber(level: Int, headingNumbers: inout [Int]) {
        
        guard type.isNumberedItem else { return }
        
        if headingNumbers[level] > 0 {
            headingNumber = headingNumbers[level] + 1
        } else {
            headingNumber = 1
        }
        
        let liIndex = blocks.count - 1
        let listIndex = blocks.count - 2
        if liIndex > 0 && blocks.blocks[liIndex].isListItem {
            blocks.blocks.remove(at: liIndex)
            if listIndex >= 0 && blocks.blocks[listIndex].tag == "ol" {
                blocks.blocks.remove(at: listIndex)
            }
        }
    }
    
    /// Another hash symbol
    func incrementHashCount() -> Bool {
        hashCount += 1
        return hashCount >= 1 && hashCount <= 6
    }
    
    func makeOrdinary() {
        type = .ordinaryText
        headingLevel = 0
        if blocks.last.isHeadingTag {
            blocks.removeLast()
        }
    }
    
    func makeFollowOn(previousLine: MkdownLine) {
        type = .followOn
        blocks = MkdownBlockStack()
        for block in previousLine.blocks.blocks {
            blocks.append(block)
        }
    }
    
    var followOn: Bool {
        return type == .followOn
    }
    
    func makeHTML() {
        type = .html
    }
    
    func makeHorizontalRule() {
        type = .horizontalRule
    }
    
    func carryBlockquotesForward(lastLine: MkdownLine) {
        var insertionPoint = 0
        if blocks.count > 0 && blocks.blocks[0].isBlockquote { return }
        for block in lastLine.blocks.blocks {
            if block.isBlockquote {
                blocks.blocks.insert(MkdownBlock("blockquote"), at: insertionPoint)
                insertionPoint += 1
            } else {
                return
            }
        }
    }
    
    /// Make this line an unordered (bulleted) list item.
    func makeUnordered(previousLine: MkdownLine, previousNonBlankLine: MkdownLine) {
        makeListItem(requestedType: .unorderedItem,
                     cited: false,
                     previousLine: previousLine,
                     previousNonBlankLine: previousNonBlankLine)
    }
    
    /// Make this line an ordered (numbered) list item.
    func makeOrdered(previousLine: MkdownLine, previousNonBlankLine: MkdownLine) {
        makeListItem(requestedType: .orderedItem,
                     cited: false,
                     previousLine: previousLine,
                     previousNonBlankLine: previousNonBlankLine)
    }
    
    /// Make this line a footnote item.
    func makeFootnoteItem(previousLine: MkdownLine, previousNonBlankLine: MkdownLine) {
        makeListItem(requestedType: .footnoteItem,
                     cited: false,
                     previousLine: previousLine,
                     previousNonBlankLine: previousNonBlankLine)
        addParagraph()
    }
    
    /// Make this line a citation item.
    func makeCitationItem(cited: Bool, previousLine: MkdownLine, previousNonBlankLine: MkdownLine) {
        makeListItem(requestedType: .citationItem,
                     cited: cited,
                     previousLine: previousLine,
                     previousNonBlankLine: previousNonBlankLine)
        addParagraph()
    }
    
    /// Make this line a list item of the prescribed type.
    func makeListItem(requestedType: MkdownLineType,
                      cited: Bool,
                      previousLine: MkdownLine,
                      previousNonBlankLine: MkdownLine) {
        
        // Set the line type to the right sort of list.
        self.type = requestedType
        
        var listTag = "ul"
        if requestedType.isNumberedItem {
            listTag = "ol"
        } else if requestedType.isDefItem {
            listTag = "dl"
        }
        
        // If the previous line was blank, then let's look at the last non-blank line.
        var lastPossibleListItem = previousLine
        if previousLine.type == .blank {
            lastPossibleListItem = previousNonBlankLine
        }
        
        // Is this the first item in a new list, or the
        // continuation of an existing list?
        let listIndex = self.blocks.listPointers.count
        var continueList = false
        var lastList = MkdownBlock()
        var lastListItem = MkdownBlock()
        if listIndex < lastPossibleListItem.blocks.listPointers.count {
            lastList = lastPossibleListItem.blocks.getListBlock(atLevel: listIndex)
            lastListItem = lastPossibleListItem.blocks.getListItem(atLevel: listIndex)
            if lastList.tag == listTag && lastListItem.tag == "li" {
                continueList = true
            }
        }
        
        let listItem = MkdownBlock("li")
        if requestedType == .footnoteItem {
            listItem.footnoteItem = true
        } else if requestedType == .citationItem {
            listItem.citationItem = true
            if !cited {
                listItem.notCited = true
            }
        }
        if continueList {
            if previousLine.type == .blank {
                lastList.listWithParagraphs = true
                if previousLine.blocks.listPointers.count <= listIndex {
                    previousLine.blocks.append(lastList)
                }
            }
            blocks.append(lastList)
            listItem.itemNumber = lastListItem.itemNumber + 1
        } else {
            let newList = MkdownBlock(listTag)
            if requestedType == .footnoteItem {
                newList.footnoteItem = true
            } else if requestedType == .citationItem {
                newList.citationItem = true
            }
            blocks.append(newList)
            listItem.itemNumber = 1
        }
        blocks.append(listItem)
    }
    
    /// Make this line a Definition Line.
    func makeDefItem(requestedType: MkdownLineType,
                     previousLine: MkdownLine,
                     previousBlankLIne: MkdownLine,
                     previousDefLine: MkdownLine) {
        
        // Ensure we're working with a valid line type.
        guard requestedType == .defTerm || requestedType == .defDefinition else {
            return
        }
        
        if requestedType == .defDefinition {
            switch previousLine.type {
            case .defTerm, .defDefinition:
                break
            case .ordinaryText:
                previousLine.makeDefItem(requestedType: .defTerm,
                                         previousLine: previousBlankLIne,
                                         previousBlankLIne: previousBlankLIne,
                                         previousDefLine: previousDefLine)
            default:
                return
            }
        }
        
        // Set the line type to the right sort of item.
        self.type = requestedType
        
        let listTag = "dl"
        var itemTag = "dt"
        if requestedType == .defDefinition {
            itemTag = "dd"
        }
        
        if requestedType == .defTerm {
            blocks.removeParaTag()
        }
        
        var continueList = previousDefLine.type.isDefItem
        
        // Is this the first item in a new list, or the
        // continuation of an existing list?
        let listIndex = self.blocks.listPointers.count
        var lastList = MkdownBlock()
        var lastDefItem = MkdownBlock()
        if listIndex < previousDefLine.blocks.listPointers.count {
            lastList = previousDefLine.blocks.getListBlock(atLevel: listIndex)
            lastDefItem = previousDefLine.blocks.getDefItem(atLevel: listIndex)
            if lastList.tag == listTag
                && (lastDefItem.tag == "dt" || lastDefItem.tag == "dd") {
                continueList = true
            } else {
                continueList = false
            }
        } else {
            continueList = false
        }
        
        let listItem = MkdownBlock(itemTag)

        if continueList {
            if requestedType != .defDefinition {
                previousBlankLIne.blocks.append(lastList)
            }
            blocks.append(lastList)
            listItem.itemNumber = lastDefItem.itemNumber + 1
        } else {
            let newList = MkdownBlock(listTag)
            blocks.append(newList)
            listItem.itemNumber = 1
        }
        blocks.append(listItem)
    }
    
    /// Try to continue open list blocks from previous lines, based on this line's indention level.
    /// - Parameters:
    ///   - previousLine: The line before this one.
    ///   - previousNonBlankLine: The last non-blank line before this one.
    ///   - forLevel: The indention level, where 1 means four spaces or a tab.
    /// - Returns: True if blocks were available and copied for the indicated level.
    func continueBlock(previousLine: MkdownLine,
                       previousNonBlankLine: MkdownLine,
                       forLevel: Int) -> Bool {
        
        // Which of the two passed lines should we examine?
        var lastPossibleListItem = previousLine
        if previousLine.type == .blank {
            lastPossibleListItem = previousNonBlankLine
        }
        
        // See whether we have list blocks to continue.
        let listIndex = forLevel - 1
        
        var continueList = false
        var lastList = MkdownBlock()
        var lastListItem = MkdownBlock()
        if listIndex < lastPossibleListItem.blocks.listPointers.count {
            lastList = lastPossibleListItem.blocks.getListBlock(atLevel: listIndex)
            lastListItem = lastPossibleListItem.blocks.getListItem(atLevel: listIndex)
            if lastList.isListTag && lastListItem.isListItem {
                continueList = true
                self.blocks.append(lastList)
                self.blocks.append(lastListItem)
                if previousLine.type == .blank
                    && previousLine.blocks.listPointers.count <= listIndex {
                    previousLine.blocks.append(lastList)
                    previousLine.blocks.append(lastListItem)
                }
            }
        }
        return continueList
    }
    
    func continueFootnoteOrCitation(line: MkdownLine) -> Bool {
        var continueList = false
        var lastList = MkdownBlock()
        var lastListItem = MkdownBlock()
        if line.blocks.listPointers.count > 0 {
            lastList = line.blocks.getListBlock(atLevel: 0)
            lastListItem = line.blocks.getListItem(atLevel: 0)
            if lastList.isListTag {
                continueList = true
                self.blocks.insert(lastList, at: 0)
                if lastListItem.isListItem {
                    self.blocks.insert(lastListItem, at: 1)
                }
            }
        }
        return continueList
    }
    
    func makeTableLine(requestedType: MkdownLineType, columnStyles: [String]) {
        type = requestedType
        blocks.removeParaTag()
        blocks.addTableTag()
        self.columnStyles = columnStyles
    }
    
    func addParagraph() {
        blocks.addParaTag()
    }
    
    func display() {
        print(" ")
        print("MkdownLine.display")
        print("Input line: '\(line)'")
        print("Line type: \(type)")
        if indentLevels > 0 {
            print("Indent levels: \(indentLevels)")
        }
        if type == .heading {
            print("Heading level: \(headingLevel)")
        }
        if isEmpty {
            print("Is Empty? \(isEmpty)")
        }
        if quoteLevel > 0 {
            print("Quote Level = \(quoteLevel)")
        }
        if hashCount > 0 {
            print("Hash count: \(hashCount)")
        }
        if repeatCount > 1 {
            print("Repeating char of \(repeatingChar), repeated \(repeatCount) times, only repeating chars? \(onlyRepeating)")
        }
        if headingUnderlining {
            print("Heading Underlining")
        }
        if trailingSpaceCount > 0 {
            print ("Trailing space count: \(trailingSpaceCount)")
        }
        if endsWithLineBreak {
            print("Ends with line break? \(endsWithLineBreak)")
        }
        if horizontalRule {
            print("Horizontal Rule")
        }
        if startMathBlock {
            print("Start Math Block")
        }
        if finishMathBlock {
            print("Finish Math Block")
        }
        if leadingPipe {
            print("Leading Pipe Char, Pipe Count = \(pipeCount), Only Table Delim Chars? \(onlyTableDelimChars)")
        }
        print("Checkbox: '\(checkBox)'")
        print("Text: '\(text)'")
        print("List Pointers Count: \(blocks.listPointers.count)")
        if columnStyles.count > 0 {
            print("Column Styles")
            for style in columnStyles {
                print("  - \(style)")
            }
        }
        blocks.display()
    }
}
