//
//  Array+Custom.swift
//  SWAPilot
//

import UIKit

/// Extension on Array, providing a way to split based on a predicate
extension Array {

    mutating func remove(if predicate: (Element) -> Bool) -> [Element] {
        var removedCount: Int = 0
        var removed: [Element] = []
        
        for (index, element) in self.enumerated() {
            if predicate(element) {
                removed.append(self.remove(at: index-removedCount))
                removedCount += 1
            }
        }
        return removed
    }
}

extension Array where Element: Comparable {

    func sortedDescending() -> [Element] {
        return self.sorted { $0 > $1 }
    }
}
