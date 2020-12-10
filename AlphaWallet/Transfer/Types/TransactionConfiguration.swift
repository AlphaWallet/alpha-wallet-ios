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
        guard !hasUserAdjustedGasLimit else { return }
        gasLimit = estimate
    }

    mutating func set(nonce: Int) {
        self.nonce = nonce
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
    case slow
    case standard
    case fast
    case rapid
    case custom

    static var sortedThirdPartyFastestFirst: [TransactionConfigurationType] {
        //We intentionally do not include `.standard`
        [.rapid, .fast, .slow]
    }

    var title: String {
        switch self {
        case .standard:
            return R.string.localizable.transactionConfigurationTypeAverage()
        case .slow:
            return R.string.localizable.transactionConfigurationTypeSlow()
        case .fast:
            return R.string.localizable.transactionConfigurationTypeFast()
        case .rapid:
            return R.string.localizable.transactionConfigurationTypeRapid()
        case .custom:
            return R.string.localizable.transactionConfigurationTypeCustom()
        }
    }

    var estimatedProcessingTime: String {
        switch self {
        case .standard:
            return R.string.localizable.transactionConfigurationTypeAverageTime()
        case .slow:
            return R.string.localizable.transactionConfigurationTypeSlowTime()
        case .fast:
            return R.string.localizable.transactionConfigurationTypeFastTime()
        case .rapid:
            return R.string.localizable.transactionConfigurationTypeRapidTime()
        case .custom:
            return ""
        }
    }
}

extension TransactionConfiguration {
    static func == (lhs: TransactionConfiguration, rhs: TransactionConfiguration) -> Bool {
        return lhs.gasPrice == rhs.gasPrice && lhs.gasLimit == rhs.gasLimit && lhs.data == rhs.data && lhs.nonce == rhs.nonce
    }
}
