//
//  WeakRef.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.04.2022.
//

import Foundation

public class WeakRef<T: AnyObject> {
    public weak var object: T?
    public init(object: T) {
        self.object = object
    }
}
