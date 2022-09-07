// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

public struct TransactionConfiguration {
    public var gasPrice: BigInt
    public var gasLimit: BigInt
    public var data: Data
    public var nonce: Int?
    public var hasUserAdjustedGasPrice: Bool
    public var hasUserAdjustedGasLimit: Bool

    public init(gasPrice: BigInt, gasLimit: BigInt, data: Data = .init(), nonce: Int? = nil, hasUserAdjustedGasPrice: Bool = false, hasUserAdjustedGasLimit: Bool = false) {
        self.gasPrice = gasPrice
        self.gasLimit = gasLimit
        self.data = data
        self.nonce = nonce
        self.hasUserAdjustedGasPrice = hasUserAdjustedGasPrice
        self.hasUserAdjustedGasLimit = hasUserAdjustedGasLimit
    }

    public mutating func setEstimated(gasPrice estimate: BigInt) {
        guard !hasUserAdjustedGasPrice else { return }
        gasPrice = estimate
    }

    public mutating func setEstimated(gasLimit estimate: BigInt) {
        guard !hasUserAdjustedGasLimit else { return }
        gasLimit = estimate
    }

    public mutating func set(nonce: Int) {
        self.nonce = nonce
    }

    public init(transaction: UnconfirmedTransaction, server: RPCServer) {
        let maxGasLimit = GasLimitConfiguration.maxGasLimit(forServer: server)
        let maxPrice: BigInt = GasPriceConfiguration.maxPrice(forServer: server)
        let defaultPrice: BigInt = GasPriceConfiguration.defaultPrice(forServer: server)
        self.init(
            gasPrice: min(max(transaction.gasPrice ?? defaultPrice, GasPriceConfiguration.minPrice), maxPrice),
            gasLimit: min(transaction.gasLimit ?? maxGasLimit, maxGasLimit),
            data: transaction.data ?? Data()
        )
    }
}

public enum TransactionConfigurationType: Int, CaseIterable {
    case slow
    case standard
    case fast
    case rapid
    case custom

    public static var sortedThirdPartyFastestFirst: [TransactionConfigurationType] {
        //We intentionally do not include `.standard`
        [.rapid, .fast, .slow]
    }
}

extension TransactionConfiguration {
    public static func == (lhs: TransactionConfiguration, rhs: TransactionConfiguration) -> Bool {
        return lhs.gasPrice == rhs.gasPrice && lhs.gasLimit == rhs.gasLimit && lhs.data == rhs.data && lhs.nonce == rhs.nonce
    }
}
