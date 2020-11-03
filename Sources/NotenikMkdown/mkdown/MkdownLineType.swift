//
//  MkdownLineType.swift
//  Notenik
//
//  Created by Herb Bowie on 3/1/20.
//  Copyright © 2020 Herb Bowie (https://powersurgepub.com)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

enum MkdownLineType {
    case blank
    case code
    case followOn
    case h1Underlines
    case h2Underlines
    case heading
    case horizontalRule
    case html
    case linkDef
    case linkDefExt
    case footnoteDef
    case footnoteItem
    case orderedItem
    case ordinaryText
    case tableOfContents
    case unorderedItem
    
    var isListItem: Bool {
        return self == .orderedItem || self == .unorderedItem || self == .footnoteItem
    }
    
    var hasText: Bool {
        return self != .blank && self != .h1Underlines && self != .h2Underlines && self != .horizontalRule && self != .linkDefExt && self != .linkDefExt
    }
    
    var textMayContinue: Bool {
        switch self {
        case .orderedItem, .ordinaryText, .unorderedItem, .footnoteItem:
            return true
        default:
            return false
        }
    }
}


