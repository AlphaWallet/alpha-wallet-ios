//
//  ExecuteOnceOnly.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 21/12/21.
//

import Foundation

public typealias ExecuteOnceOnlyClosure = (() -> Void)

public class ExecuteOnceOnly {

    private var didFire: Bool

    public init() {
        didFire = false
    }

    public func once(completion: ExecuteOnceOnlyClosure) {
        guard !didFire else { return }
        completion()
        didFire = true
    }

}
