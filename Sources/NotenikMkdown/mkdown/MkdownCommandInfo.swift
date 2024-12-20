//
//  MkdownCommandInfo.swift
//  NotenikMkdown
//
//  Created by Herb Bowie on 6/21/24.
//
//  Copyright © 2024 Herb Bowie (https://hbowie.net)
//
//  This programming code is published as open source software under the
//  terms of the MIT License (https://opensource.org/licenses/MIT).
//

import Foundation

import NotenikUtils

public class MkdownCommandInfo {
    
    public var validCommand = false
    public var prefix = ""
    public var command = ""
    public var commandComplete: Bool {
        get {
            return _commandComplete
        }
        set {
            _commandComplete = newValue
            commandWithParms = false
            if _commandComplete {
                switch command {
                case MkdownConstants.segmentCmd:
                    commandWithParms = true
                case MkdownConstants.bylineCmd, "by":
                    commandWithParms = true
                case MkdownConstants.quoteFromCmd:
                    commandWithParms = true
                case MkdownConstants.injectCmd:
                    commandWithParms = true
                default:
                    break
                }
            }
        }
    }
           var _commandComplete = false
           var commandWithParms = false
    public var includeStyle = ""
    public var mods = ""
    public var parms = ""
    public var individualParms: [String] = []
           var splitPerformed = false
    public var tocLevelStart: Character = " "
    public var tocLevelEnd: Character = "9"
    public var suffix = ""
    public var lineType: MkdownLineType = .ordinaryText
    
    public var tocLevelStartInt: Int {
        let int = Int(String(tocLevelStart))
        if int != nil && int! >= 0 && int! <= 9 {
            return int!
        } else {
            return 0
        }
    }
    
    public var tocLevelEndInt: Int {
        let int = Int(String(tocLevelEnd))
        if int != nil && int! >= 0 && int! <= 9 {
            return int!
        } else {
            return 999
        }
    }
    
    public func getParmElement() -> String {
        return getParm(atIndex: 0)
    }
    
    public func getParmKlass() -> String {
        return getParm(atIndex: 1)
    }
    
    public func getParmID() -> String {
        return getParm(atIndex: 2)
    }
    
    public func getParmStyle() -> String {
        return getParm(atIndex: 3)
    }
    
    public func getParm(atIndex: Int) -> String {
        splitParms()
        if atIndex >= 0 && atIndex < individualParms.count {
            return individualParms[atIndex]
        } else {
            return ""
        }
    }
    
    public func splitParms(sep: Character = "|") {
        guard !splitPerformed else { return }
        individualParms = []
        splitPerformed = true
        guard parms.count > 0 else { return }
        var str = SolidString()
        for c in parms {
            if c == sep {
                individualParms.append(str.description)
                str = SolidString()
            } else {
                str.append(c)
            }
        }
        if !str.isEmpty {
            individualParms.append(str.description)
        }
    }
}
