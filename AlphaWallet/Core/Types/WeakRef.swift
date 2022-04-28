//
//  WeakRef.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.04.2022.
//

import Foundation

class WeakRef<T: AnyObject> {
    weak var object: T?
    init(object: T) {
        self.object = object
    }
}
