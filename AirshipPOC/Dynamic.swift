//
//  Dynamic.swift
//
//  Created by Dino Bartosak on 25/09/16.
//  Copyright © 2016 Toptal. All rights reserved.
//

class Dynamic<T> {
    typealias Listener = (T) -> Void
    
    var listener: Listener?
    
    func bind(_ listener: Listener?) {
        self.listener = listener
    }
    
    func bindAndFire(_ listener: Listener?) {
        self.listener = listener
        listener?(value)
    }
    
    var value: T {
        didSet {
            listener?(value)
        }
    }
    // Identifier Name violation is ok here
    // swiftlint:disable:next identifier_name
    init(_ v: T) {
        value = v
    }
    
}
