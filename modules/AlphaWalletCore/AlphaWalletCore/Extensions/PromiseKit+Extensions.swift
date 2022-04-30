//
//  PromiseKit+Extensions.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation
import PromiseKit

extension PromiseKit.Result {
    public var optionalValue: T? {
        switch self {
        case .fulfilled(let value):
            return value
        case .rejected:
            return nil
        }
    }
}