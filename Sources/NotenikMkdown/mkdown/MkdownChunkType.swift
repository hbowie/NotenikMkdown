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
    case onlyAPoundSign
    case hashtag
    case hashtagEnd
    
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
    case tableHeaderPipeExtra
    case headerColumnStart
    case headerColumnFinish
    case headerColumnFinishAndStart
    case tableDataPipe
    case tableDataPipeExtra
    case dataColumnStart
    case dataColumnFinish
    case dataColumnFinishAndStart

    
    case startCheckBox
    case checkBoxContent
    case endCheckBoxChecked
    case endCheckBoxUnchecked
    
    case tilde
    
    case startStrikethrough1
    case startStrikethrough2
    case endStrikethrough1
    case endStrikethrough2
    
    case equalSign
    
    case startHighlight1
    case startHighlight2
    case endHighlight1
    case endHighlight2
    
    case startSubscript
    case endSubscript
    
    case startSuperscript
    case endSuperscript
    
    var extraPipe: Bool {
        switch self {
        case .tableHeaderPipeExtra, .tableDataPipeExtra:
            return true
        default:
            return false
        }
    }
    
    var notExtra: Bool {
        switch self {
        case .tableHeaderPipeExtra, .tableDataPipeExtra:
            return false
        default:
            return true
        }
    }
    
    var tablePipePrelim: Bool {
        switch self {
        case .tableHeaderPipe, .tableHeaderPipeExtra, .tableDataPipe, .tableDataPipeExtra:
            return true
        default:
            return false
        }
    }
    
    var tablePipePending: Bool {
        switch self {
        case .tableHeaderPipe, .tableDataPipe:
            return true
        default:
            return false
        }
    }
    
    var makeExtra: MkdownChunkType {
        switch self {
        case .tableHeaderPipe, .tableHeaderPipeExtra:
            return .tableHeaderPipeExtra
        default:
            return .tableDataPipeExtra
        }
    }
    
    func makeFinal(position: linePosition) -> MkdownChunkType {
        switch self {
        case .tableHeaderPipe, .tableHeaderPipeExtra:
            switch position {
            case .start: return .headerColumnStart
            case .middle: return .headerColumnFinishAndStart
            case .finish: return .headerColumnFinish
            }
        case .tableDataPipe, .tableDataPipeExtra:
            switch position {
            case .start: return .dataColumnStart
            case .middle: return .dataColumnFinishAndStart
            case .finish: return .dataColumnFinish
            }
        default:
            return self
        }
    }
    
    enum linePosition {
        case start
        case middle
        case finish
    }
}


