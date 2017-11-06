//
//  Configure.swift
//  SwiftParrotMinidrone
//
//  Created by ST14580 on 2017/11/06.
//  Copyright © 2017年 ST14580. All rights reserved.
//

import Foundation

struct Configure {
    static let ModeKey = "configure.mode"
    enum Mode: Int {
        case mode1
        case mode2
    }
    
    static var mode: Mode {
        get {
            let defaults = UserDefaults.standard
            let mode: Mode!
            if defaults.object(forKey: Configure.ModeKey) == nil {
                //  default is mode2
                mode = Mode.mode2
                defaults.set(mode.rawValue, forKey: Configure.ModeKey)
            } else {
                mode = Mode(rawValue: defaults.integer(forKey: Configure.ModeKey))
            }
            
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Configure.ModeKey)
            print("set mode :", newValue)
        }
    }
}
