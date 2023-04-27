//
//  MkdownLineType.swift
//  Notenik
//
//  Created by Herb Bowie on 3/1/20.
//  Copyright © 2020 - 2023 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

enum MkdownLineType {
    case blank
    case biblio
    case citationDef
    case citationItem
    case code
    case codeFence
    case defTerm
    case defDefinition
    case followOn
    case h1Underlines
    case h2Underlines
    case heading
    case horizontalRule
    case html
    case include
    case index
    case linkDef
    case linkDefExt
    case footer
    case footnoteDef
    case footnoteItem
    case header
    case math
    case metadata
    case nav
    case orderedItem
    case ordinaryText
    case random
    case search
    case tableHeader
    case tableDelims
    case tableData
    case tableOfContents
    case tagsCloud
    case tagsOutline
    case teasers
    case tocForCollection
    case unorderedItem
    case sortTable
    
    var isNumberedItem: Bool {
        return self == .orderedItem || self == .footnoteItem || self == .citationItem
    }
    
    var isDefItem: Bool {
        return self == .defTerm || self == .defDefinition
    }
    
    var isListItem: Bool {
        return isNumberedItem || self == .unorderedItem || isDefItem
    }
    
    var hasText: Bool {
        return self != .blank && self != .h1Underlines && self != .h2Underlines && self != .horizontalRule && self != .linkDefExt && self != .linkDefExt
    }
    
    var textMayContinue: Bool {
        switch self {
        case .orderedItem, .ordinaryText, .unorderedItem, .footnoteItem, .citationItem, .defDefinition, .followOn:
            return true
        default:
            return false
        }
    }
}
