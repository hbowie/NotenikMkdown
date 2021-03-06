//
//  MkdownChunkType.swift
//  Notenik
//
//  Created by Herb Bowie on 3/3/20.
//  Copyright © 2020 Herb Bowie (https://hbowie.net)
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
}
