//
//  MkdownChunkType.swift
//  Notenik
//
//  Created by Herb Bowie on 3/3/20.
//  Copyright © 2020 - 2022 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

enum MkdownChunkType {
    
    case plaintext
    
    case asterisk
    case underline
    
    case startStrong1
    case startStrong2
    case endStrong1
    case endStrong2
    
    case startEmphasis
    case endEmphasis
    
    case backSlash
    case literal
    
    case backtickQuote
    case startCode
    case endCode
    case backtickQuote2
    case skipSpace
    
    case leftAngleBracket
    case tagStart
    case autoLinkStart
    
    case rightAngleBracket
    case tagEnd
    case autoLinkEnd
    
    case atSign
    case colon
    
    case ampersand
    case entityStart
    
    case leftSquareBracket
    case rightSquareBracket
    case caret
    
    case poundSign
    case hashtag
    
    case leftParen
    case rightParen
    
    case exclamationMark
    case startImage
    
    case singleQuote
    case doubleQuote
    
    case startLinkText
    case startWikiLink1
    case startWikiLink2
    
    case endLinkText
    case endWikiLink1
    case endWikiLink2
    
    case plainPipe
    case startWikiLinkTitle
    
    case startLinkLabel
    case endLinkLabel
    
    case startLink
    case endLink
    
    case startTitle
    case endTitle
    
    case startFootnoteLabel1
    case startFootnoteLabel2
    case endFootnoteLabel
    
    case startCitationLabel1
    case startCitationLabel2
    case endCitationLabel
    case startCitationLocator
    case endCitationLocator
    
    case singleCurlyQuoteOpen
    case singleCurlyQuoteClose
    case apostrophe
    
    case doubleCurlyQuoteOpen
    case doubleCurlyQuoteClose
    
    case ellipsis
    
    case endash
    case emdash
    
    case dollarSign
    case startMath
    case endMath
    case skipMath
    
    case tableHeaderPipe
    case headerColumnStart
    case headerColumnFinish
    case headerColumnFinishAndStart
    case tableDataPipe
    case dataColumnStart
    case dataColumnFinish
    case dataColumnFinishAndStart
    case tablePipeExtra
    
    case startCheckBox
    case checkBoxContent
    case endCheckBoxChecked
    case endCheckBoxUnchecked
    
    case tilde
    
    case startStrikethrough1
    case startStrikethrough2
    case endStrikethrough1
    case endStrikethrough2
    
    case startSubscript
    case endSubscript
    
    case startSuperscript
    case endSuperscript
}
