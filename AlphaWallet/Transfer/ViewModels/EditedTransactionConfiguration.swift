// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import AlphaWalletFoundation

struct EditedTransactionConfiguration {
    private let formatter = EtherNumberFormatter.full
    private let blockchainParams: BlockchainParams

    var gasPrice: BigUInt {
        return formatter.number(from: String(gasPriceRawValue), units: UnitConfiguration.gasPriceUnit).flatMap { BigUInt($0) } ?? BigUInt()
    }

    var gasLimit: BigUInt {
        BigUInt(String(gasLimitRawValue), radix: 10) ?? BigUInt()
    }

    var data: Data {
        if dataRawValue.isEmpty {
            return .init()
        } else {
            return .init(hex: dataRawValue.drop0x)
        }
    }

    var gasPriceRawValue: Int
    var gasLimitRawValue: Int
    var dataRawValue: String
    var nonceRawValue: Int?

    var overriddenMaxGasPrice: Int?
    var overriddenMaxGasLimit: Int?

    var defaultMinGasLimit: Int {
        return Int(blockchainParams.minPrice / BigUInt(UnitConfiguration.gasPriceUnit.rawValue))
    }

    var defaultMinGasPrice: Int {
        return Int(blockchainParams.minPrice / BigUInt(UnitConfiguration.gasPriceUnit.rawValue))
    }

    private let defaultMaxGasLimit: Int
    private let defaultMaxGasPrice: Int

    var maxGasPrice: Int {
        if let overriddenValue = overriddenMaxGasPrice {
            return overriddenValue
        } else {
            return defaultMaxGasPrice
        }
    }

    var maxGasLimit: Int {
        if let overriddenValue = overriddenMaxGasLimit {
            return overriddenValue
        } else {
            return defaultMaxGasLimit
        }
    }

    mutating func updateMaxGasLimitIfNeeded(_ value: Int) {
        if value > defaultMaxGasLimit {
            overriddenMaxGasLimit = value
        } else if value < defaultMinGasLimit {
            overriddenMaxGasLimit = nil
        }
    }

    mutating func updateMaxGasPriceIfNeeded(_ value: Int) {
        if value > defaultMaxGasPrice {
            overriddenMaxGasPrice = value
        } else if value < defaultMaxGasPrice {
            overriddenMaxGasPrice = nil
        }
    }

    init(configuration: TransactionConfiguration, blockchainParams: BlockchainParams) {
        self.blockchainParams = blockchainParams
        defaultMaxGasLimit = Int(blockchainParams.maxGasLimit)
        gasLimitRawValue = Int(configuration.gasLimit.description) ?? 21000
        gasPriceRawValue = Int(configuration.gasPrice / BigUInt(UnitConfiguration.gasPriceUnit.rawValue))
        nonceRawValue = Int(configuration.nonce.flatMap { String($0) } ?? "")
        dataRawValue = configuration.data.hexEncoded.add0x
        defaultMaxGasPrice = Int(blockchainParams.maxPrice / BigUInt(UnitConfiguration.gasPriceUnit.rawValue))

        updateMaxGasLimitIfNeeded(gasLimitRawValue)
        updateMaxGasPriceIfNeeded(gasPriceRawValue)
    }

    var configuration: TransactionConfiguration {
        return .init(gasPrice: gasPrice, gasLimit: gasLimit, data: data, nonce: nonceRawValue)
    }

    var isGasPriceValid: Bool {
        return gasPrice >= 0
    }

    var isGasLimitValid: Bool {
        return gasLimit <= ConfigureTransaction.gasLimitMax && gasLimit >= 0
    }

    var totalFee: BigUInt {
        return gasPrice * gasLimit
    }

    var isTotalFeeValid: Bool {
        return totalFee <= ConfigureTransaction.gasFeeMax && totalFee >= 0
    }

    var isNonceValid: Bool {
        guard let nonce = nonceRawValue else { return true }
        return nonce >= 0
    }
}
