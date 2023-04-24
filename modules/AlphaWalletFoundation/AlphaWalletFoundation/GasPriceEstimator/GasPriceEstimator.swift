//
//  LegacyGasPriceEstimator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.05.2022.
//

import Foundation
import BigInt
import Combine
import AlphaWalletCore
import AlphaWalletLogger

public protocol GasPriceEstimator {
    var gasPrice: FillableValue<GasPrice> { get }
    var gasPricePublisher: AnyPublisher<FillableValue<GasPrice>, Never> { get }
    var estimatesPublisher: AnyPublisher<GasEstimates, Never> { get }
    var state: AnyPublisher<GasPriceEstimatorState, Never> { get }
    var selectedGasSpeed: GasSpeed { get }

    func set(gasSpeed: GasSpeed)
}

public enum GasPriceEstimatorState {
    case idle
    case loading
    case done
    case tick(Int)

    init(state: Scheduler.State) {
        switch state {
        case .idle:
            self = .idle
        case .tick(let int):
            self = .tick(int)
        case .loading:
            self = .loading
        case .done(let result):
            self = .done
        }
    }
}

extension RPCServer {
    var supportsEip1559: Bool {
        switch self {
        case .main, .polygon, .goerli: return true
        case .binance_smart_chain, .heco, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, .xDai, .custom, .callisto, .classic, .binance_smart_chain_testnet, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .mumbai_testnet, .optimistic, .cronosTestnet, .palm, .palmTestnet, .ioTeX, .ioTeXTestnet, .optimismGoerli, .arbitrumGoerli, .cronosMainnet, .okx, .sepolia: return false
        }
    }

    func defaultLegacyGasPrice(usingGasPrice: BigUInt?) -> BigUInt {
        switch serverWithEnhancedSupport {
        case .xDai:
            return GasPriceConfiguration.xDaiGasPrice
        case .main, .polygon, .binance_smart_chain, .heco, .rinkeby, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
            let minPrice: BigUInt = GasPriceConfiguration.minPrice
            let maxPrice: BigUInt = GasPriceConfiguration.maxPrice(forServer: self)
            let defaultPrice: BigUInt = GasPriceConfiguration.defaultPrice(forServer: self)
            if let gasPrice = usingGasPrice, gasPrice > 0 {
                //We don't compare to `GasPriceConfiguration.minPrice` because if the transaction already has a price (from speedup/cancel or dapp), we should use it
                return min(gasPrice, maxPrice)
            } else {
                let defaultGasPrice = min(max(usingGasPrice ?? defaultPrice, minPrice), maxPrice)
                return defaultGasPrice
            }
        }
    }
}
