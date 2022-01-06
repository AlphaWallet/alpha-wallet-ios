//
//  ExecuteOnceOnly.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 21/12/21.
//

import Foundation

typealias ExecuteOnceOnlyClosure = (() -> Void)

class ExecuteOnceOnly {

    private var didFire: Bool

    init() {
        didFire = false
    }

    func once(completion: ExecuteOnceOnlyClosure) {
        guard !didFire else { return }
        completion()
        didFire = true
    }

}
