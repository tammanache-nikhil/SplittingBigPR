//
//  Int+Custom.swift
//  SWAPilot
//

import Foundation

extension Int {
    
    var toSeconds: Int {
           return self*60
    }
    
    var toMinutes: Int {
        self/60
    }
    
    var toRoundedSeconds: Int {
        return Int(round(Double(self)/60.0)*60)
    }
    
    /// Use to create a decimal string
    var toDecimalString: String? {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        return numberFormatter.string(for: self)
    }
}
