//
//  GasPriceEstimator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.05.2022.
//

import Foundation
import PromiseKit
import BigInt
import APIKit
import JSONRPCKit

public final class GasPriceEstimator {
    private let analytics: AnalyticsLogger

    public init(analytics: AnalyticsLogger) {
        self.analytics = analytics
    }

    public func shouldUseEstimatedGasPrice(_ estimatedGasPrice: BigUInt, forTransaction transaction: UnconfirmedTransaction) -> Bool {
        //Gas price may be specified in the transaction object, and it will be if we are trying to speedup or cancel a transaction. The replacement transaction will be automatically assigned a slightly higher gas price. We don't want to override that with what we fetch back from gas price estimate if the estimate is lower
        if let specifiedGasPrice = transaction.gasPrice, specifiedGasPrice > estimatedGasPrice {
            return false
        } else {
            return true
        }
    }

    public func estimateGasPrice(server: RPCServer) -> Promise<GasEstimates> {
        if EtherscanGasPriceEstimator.supports(server: server) {
            return estimateGasPriceForUsingEtherscanApi(server: server)
                .recover { _ in self.estimateGasPriceForUseRpcNode(server: server) }
        } else {
            switch server.serverWithEnhancedSupport {
            case .xDai:
                return estimateGasPriceForXDai()
            case .main, .polygon, .binance_smart_chain, .heco, .rinkeby, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
                return estimateGasPriceForUseRpcNode(server: server)
            }
        }
    }

    public func estimateDefaultGasPrice(server: RPCServer, transaction: UnconfirmedTransaction) -> BigUInt {
        switch server.serverWithEnhancedSupport {
        case .xDai:
            return GasPriceConfiguration.xDaiGasPrice
        case .main, .polygon, .binance_smart_chain, .heco, .rinkeby, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
            let maxPrice: BigUInt = GasPriceConfiguration.maxPrice(forServer: server)
            let defaultPrice: BigUInt = GasPriceConfiguration.defaultPrice(forServer: server)
            if let gasPrice = transaction.gasPrice, gasPrice > 0 {
                //We don't compare to `GasPriceConfiguration.minPrice` because if the transaction already has a price (from speedup/cancel or dapp), we should use it
                return min(gasPrice, maxPrice)
            } else {
                let defaultGasPrice = min(max(transaction.gasPrice ?? defaultPrice, GasPriceConfiguration.minPrice), maxPrice)
                return defaultGasPrice
            }
        }
    }

    private func estimateGasPriceForUsingEtherscanApi(server: RPCServer) -> Promise<GasEstimates> {
        return firstly {
            EtherscanGasPriceEstimator().fetch(server: server)
        }.get { estimates in
            infoLog("Estimated gas price with gas price estimator API server: \(server) estimate: \(estimates)")
        }.map { estimates in
            GasEstimates(standard: BigUInt(estimates.standard), others: [
                TransactionConfigurationType.slow: BigUInt(estimates.slow),
                TransactionConfigurationType.fast: BigUInt(estimates.fast),
                TransactionConfigurationType.rapid: BigUInt(estimates.rapid)
            ])
        }
    }

    private func estimateGasPriceForXDai() -> Promise<GasEstimates> {
        //xDAI node returns a much higher gas price than necessary so if it is xDAI simply return the fixed amount
        .value(.init(standard: GasPriceConfiguration.xDaiGasPrice))
    }

    private func estimateGasPriceForUseRpcNode(server: RPCServer) -> Promise<GasEstimates> {
        let getGasPrice = GetGasPrice(server: server, analytics: analytics)
        return getGasPrice.getGasEstimates()
    }
}
