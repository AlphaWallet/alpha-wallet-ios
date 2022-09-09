//
//  Repeat.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 14/3/22.
//

import Foundation

public func repeatTimes(_ times: Int, block: () -> Void) {
    for _ in 0..<times {
        block()
    }
}
