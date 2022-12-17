//
//  GasPriceEstimator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.05.2022.
//

import Foundation
import BigInt
import Combine
import AlphaWalletCore

public protocol GasPriceEstimatorType {
    func estimateGasPrice() -> AnyPublisher<GasEstimates, PromiseError>
    func estimateDefaultGasPrice(transaction: UnconfirmedTransaction) -> BigUInt
}

extension GasPriceEstimatorType {
    public func shouldUseEstimatedGasPrice(_ estimatedGasPrice: BigUInt, forTransaction transaction: UnconfirmedTransaction) -> Bool {
        //Gas price may be specified in the transaction object, and it will be if we are trying to speedup or cancel a transaction. The replacement transaction will be automatically assigned a slightly higher gas price. We don't want to override that with what we fetch back from gas price estimate if the estimate is lower
        if let specifiedGasPrice = transaction.gasPrice, specifiedGasPrice > estimatedGasPrice {
            return false
        } else {
            return true
        }
    }
}

public final class GasPriceEstimator: GasPriceEstimatorType {
    private let networkService: NetworkService
    private lazy var etherscanGasPriceEstimator = EtherscanGasPriceEstimator(networkService: networkService)
    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider, networkService: NetworkService) {
        self.networkService = networkService
        self.blockchainProvider = blockchainProvider
    }

    public func shouldUseEstimatedGasPrice(_ estimatedGasPrice: BigUInt, forTransaction transaction: UnconfirmedTransaction) -> Bool {
        //Gas price may be specified in the transaction object, and it will be if we are trying to speedup or cancel a transaction. The replacement transaction will be automatically assigned a slightly higher gas price. We don't want to override that with what we fetch back from gas price estimate if the estimate is lower
        if let specifiedGasPrice = transaction.gasPrice, specifiedGasPrice > estimatedGasPrice {
            return false
        } else {
            return true
        }
    }

    public func estimateGasPrice() -> AnyPublisher<GasEstimates, PromiseError> {
        if EtherscanGasPriceEstimator.supports(server: blockchainProvider.server) {
            return estimateGasPriceForUsingEtherscanApi(server: blockchainProvider.server)
                .catch { _ in self.estimateGasPriceForUseRpcNode() }
                .eraseToAnyPublisher()
        } else {
            switch blockchainProvider.server.serverWithEnhancedSupport {
            case .xDai:
                return estimateGasPriceForXDai()
            case .main, .polygon, .binance_smart_chain, .heco, .rinkeby, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
                return estimateGasPriceForUseRpcNode()
            }
        }
    }

    public func estimateDefaultGasPrice(transaction: UnconfirmedTransaction) -> BigUInt {
        switch blockchainProvider.server.serverWithEnhancedSupport {
        case .xDai:
            return GasPriceConfiguration.xDaiGasPrice
        case .main, .polygon, .binance_smart_chain, .heco, .rinkeby, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
            let maxPrice: BigUInt = GasPriceConfiguration.maxPrice(forServer: blockchainProvider.server)
            let defaultPrice: BigUInt = GasPriceConfiguration.defaultPrice(forServer: blockchainProvider.server)
            if let gasPrice = transaction.gasPrice, gasPrice > 0 {
                //We don't compare to `GasPriceConfiguration.minPrice` because if the transaction already has a price (from speedup/cancel or dapp), we should use it
                return min(gasPrice, maxPrice)
            } else {
                let defaultGasPrice = min(max(transaction.gasPrice ?? defaultPrice, GasPriceConfiguration.minPrice), maxPrice)
                return defaultGasPrice
            }
        }
    }

    private func estimateGasPriceForUsingEtherscanApi(server: RPCServer) -> AnyPublisher<GasEstimates, PromiseError> {
        return etherscanGasPriceEstimator
            .gasPriceEstimatesPublisher(server: server)
            .handleEvents(receiveOutput: { estimates in
                infoLog("Estimated gas price with gas price estimator API server: \(server) estimate: \(estimates)")
            }).map { estimates in
                GasEstimates(standard: BigUInt(estimates.standard), others: [
                    TransactionConfigurationType.slow: BigUInt(estimates.slow),
                    TransactionConfigurationType.fast: BigUInt(estimates.fast),
                    TransactionConfigurationType.rapid: BigUInt(estimates.rapid)
                ])
            }.eraseToAnyPublisher()
    }

    private func estimateGasPriceForXDai() -> AnyPublisher<GasEstimates, PromiseError> {
        //xDAI node returns a much higher gas price than necessary so if it is xDAI simply return the fixed amount
        .just(.init(standard: GasPriceConfiguration.xDaiGasPrice))
    }

    private func estimateGasPriceForUseRpcNode() -> AnyPublisher<GasEstimates, PromiseError> {
        return blockchainProvider.gasEstimatesPublisher()
    }
}
