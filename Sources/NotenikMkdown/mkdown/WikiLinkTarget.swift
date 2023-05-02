//
//  WikiLinkTarget.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 9/1/22.
//
//  Copyright © 2022 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

import NotenikUtils

/// String info specifying the target for a wiki link, with an optional path separated from an item name
/// by an optional slash. 
public class WikiLinkTarget: Comparable, CustomStringConvertible, Equatable, Identifiable {

            var _path = ""
            var _item = ""
            var _itemID = ""
    public  var matched = false
    
    public init() {
        
    }
    
    public init(_ linkText: String) {
        set(linkText)
    }
    
    public init(path: String, item: String) {
        _path = path
        _item = item
        _itemID = StringUtils.toCommon(_item)
    }
    
    public func set(_ linkText: String) {
        (_path, _item) = StringUtils.splitPath(linkText)
        _itemID = StringUtils.toCommon(_item)
    }
    
    public var isEmpty: Bool {
        return _item.isEmpty
    }
    
    public var hasPath: Bool {
        return !_path.isEmpty
    }
    
    public var description: String {
        return pathSlashItem
    }
    
    public var id: String {
        return pathSlashID
    }
    
    public var path: String {
        return _path
    }
    
    public var item: String {
        return _item
    }
    
    public var itemID: String {
        return _itemID
    }
    
    public var pathSlashItem: String {
        if path.isEmpty {
            return _item
        } else {
            return "\(_path)/\(_item)"
        }
    }
    
    public func formatWikiLink(format: WikiLinkFormat) -> String {
        switch format {
        case .common:
            return pathSlashID
        case .fileName:
            return pathSlashFilename
        }
    }
    
    public var pathSlashID: String {
        if path.isEmpty {
            return _itemID
        } else {
            return "\(path)/\(_itemID)"
        }
    }
    
    public var pathSlashFilename: String {
        let fn = StringUtils.toCommonFileName(item)
        if path.isEmpty {
            return fn
        } else {
            return "\(path)/\(fn)"
        }
    }
    
    public func display(indentLevels: Int = 0) {
        
        StringUtils.display("path = \(path), item = \(item), id = \(itemID), matched? \(matched)",
                            label: nil,
                            blankBefore: false,
                            header: "WikiLinkTarget",
                            sepLine: false, indentLevels: indentLevels)
    }
    
    public static func == (lhs: WikiLinkTarget, rhs: WikiLinkTarget) -> Bool {
        return lhs.pathSlashID == rhs.pathSlashID
    }
    
    public static func < (lhs: WikiLinkTarget, rhs: WikiLinkTarget) -> Bool {
        return lhs.pathSlashID < rhs.pathSlashID
    }
    
}
