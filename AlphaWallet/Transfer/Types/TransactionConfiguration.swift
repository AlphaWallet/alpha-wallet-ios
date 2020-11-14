// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

struct TransactionConfiguration {
    var gasPrice: BigInt
    var gasLimit: BigInt
    var data: Data
    var nonce: Int?
    var hasUserAdjustedGasPrice: Bool
    var hasUserAdjustedGasLimit: Bool

    init(gasPrice: BigInt, gasLimit: BigInt, data: Data = .init(), nonce: Int? = nil, hasUserAdjustedGasPrice: Bool = false, hasUserAdjustedGasLimit: Bool = false) {
        self.gasPrice = gasPrice
        self.gasLimit = gasLimit
        self.data = data
        self.nonce = nonce
        self.hasUserAdjustedGasPrice = hasUserAdjustedGasPrice
        self.hasUserAdjustedGasLimit = hasUserAdjustedGasLimit
    }

    mutating func setEstimated(gasPrice estimate: BigInt) {
        guard !hasUserAdjustedGasPrice else { return }
        gasPrice = estimate
    }

    mutating func setEstimated(gasLimit estimate: BigInt) {
        guard !hasUserAdjustedGasLimit else {return}
        gasLimit = estimate
    }

    init(transaction: UnconfirmedTransaction) {
        self.init(
            gasPrice: min(max(transaction.gasPrice ?? GasPriceConfiguration.defaultPrice, GasPriceConfiguration.minPrice), GasPriceConfiguration.maxPrice),
            gasLimit: min(transaction.gasLimit ?? GasLimitConfiguration.maxGasLimit, GasLimitConfiguration.maxGasLimit),
            data: transaction.data ?? Data()
        )
    }
}

enum TransactionConfigurationType: Int, CaseIterable {
    case `default`
    case custom

    var title: String {
        switch self {
        case .default:
            return R.string.localizable.tokenTransactionConfirmationDefault()
        case .custom:
            return R.string.localizable.transactionConfigurationTypeCustom()
        }
    }
}

extension TransactionConfiguration {
    static func == (lhs: TransactionConfiguration, rhs: TransactionConfiguration) -> Bool {
        return lhs.gasPrice == rhs.gasPrice && lhs.gasLimit == rhs.gasLimit && lhs.data == rhs.data && lhs.nonce == rhs.nonce
    }
}
