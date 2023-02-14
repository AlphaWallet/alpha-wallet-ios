//
//  GasPriceObject.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 10.03.2023.
//

import Foundation
import BigInt
import RealmSwift

class GasPriceObject: Object {
    @objc dynamic var primaryKey: String = ""
    @objc dynamic var gasPrice: String = ""
    @objc dynamic var maxFeePerGas: String?
    @objc dynamic var maxPriorityFeePerGas: String?

    convenience init(gasPrice: GasPrice, primaryKey: String) {
        self.init()
        self.primaryKey = primaryKey
        switch gasPrice {
        case .legacy(let gasPrice):
            self.gasPrice = gasPrice.description
        case .eip1559(let maxFeePerGas, let maxPriorityFeePerGas):
            self.maxFeePerGas = maxFeePerGas.description
            self.maxPriorityFeePerGas = maxPriorityFeePerGas.description
        }
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }
}

extension GasPrice {
    init?(object: GasPriceObject) {
        if let maxFeePerGas = object.maxFeePerGas.flatMap({ BigUInt($0) }),
           let maxPriorityFeePerGas = object.maxPriorityFeePerGas.flatMap({ BigUInt($0) }) {
            self = .eip1559(maxFeePerGas: maxFeePerGas, maxPriorityFeePerGas: maxPriorityFeePerGas)
        } else if let gasPrice = BigUInt(object.gasPrice) {
            self = .legacy(gasPrice: gasPrice)
        } else {
            return nil
        }
    }
}
