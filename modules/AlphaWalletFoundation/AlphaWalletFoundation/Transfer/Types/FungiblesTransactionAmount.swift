//
//  FungiblesTransactionAmount.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.12.2021.
//

import Foundation

public struct FungiblesTransactionAmount {
    public var value: String
    public var shortValue: String?
    public var isAllFunds: Bool = false

    public init(value: String, shortValue: String?, isAllFunds: Bool) {
        self.value = value
        self.shortValue = shortValue
        self.isAllFunds = isAllFunds
    }
}
