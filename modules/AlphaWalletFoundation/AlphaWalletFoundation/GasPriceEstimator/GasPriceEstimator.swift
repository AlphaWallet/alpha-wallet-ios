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
    func estimateGasPrice() -> AnyPublisher<GasEstimates, PromiseError>
}

extension RPCServer {
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

public final class LegacyGasPriceEstimator: GasPriceEstimator {
    private let networkService: NetworkService
    private lazy var etherscanGasPriceEstimator = EtherscanGasPriceEstimator(networkService: networkService)
    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider,
                networkService: NetworkService) {

        self.networkService = networkService
        self.blockchainProvider = blockchainProvider
    }

    public func estimateGasPrice() -> AnyPublisher<GasEstimates, PromiseError> {
        if EtherscanGasPriceEstimator.supports(server: blockchainProvider.server) {
            return estimateGasPriceForUsingEtherscanApi(server: blockchainProvider.server)
                .catch { [blockchainProvider] _ in blockchainProvider.gasEstimates() }
                .eraseToAnyPublisher()
        } else {
            switch blockchainProvider.server.serverWithEnhancedSupport {
            case .xDai:
                return .just(.init(standard: GasPriceConfiguration.xDaiGasPrice))
            case .main, .polygon, .binance_smart_chain, .heco, .rinkeby, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
                return blockchainProvider.gasEstimates()
            }
        }
    }

    private func estimateGasPriceForUsingEtherscanApi(server: RPCServer) -> AnyPublisher<GasEstimates, PromiseError> {
        return etherscanGasPriceEstimator
            .gasPriceEstimates(server: server)
            .handleEvents(receiveOutput: { estimates in
                infoLog("[Gas] Estimated gas price with gas price estimator API server: \(server) estimate: \(estimates)")
            }).eraseToAnyPublisher()
    }
}
