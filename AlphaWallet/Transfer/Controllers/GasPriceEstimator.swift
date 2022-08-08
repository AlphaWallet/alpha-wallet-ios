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

final class GasPriceEstimator {
    private let analytics: AnalyticsLogger

    init(analytics: AnalyticsLogger) {
        self.analytics = analytics
    }

    func shouldUseEstimatedGasPrice(_ estimatedGasPrice: BigInt, forTransaction transaction: UnconfirmedTransaction) -> Bool {
        //Gas price may be specified in the transaction object, and it will be if we are trying to speedup or cancel a transaction. The replacement transaction will be automatically assigned a slightly higher gas price. We don't want to override that with what we fetch back from gas price estimate if the estimate is lower
        if let specifiedGasPrice = transaction.gasPrice, specifiedGasPrice > estimatedGasPrice {
            return false
        } else {
            return true
        }
    }

    func estimateGasPrice(server: RPCServer) -> Promise<GasEstimates> {
        if EtherscanGasPriceEstimator.supports(server: server) {
            return estimateGasPriceForUsingEtherscanApi(server: server)
                .recover { _ in self.estimateGasPriceForUseRpcNode(server: server) }
        } else {
            switch server {
            case .xDai:
                return estimateGasPriceForXDai()
            case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .phi, .ioTeX, .ioTeXTestnet:
                return estimateGasPriceForUseRpcNode(server: server)
            }
        }
    }

    func estimateDefaultGasPrice(server: RPCServer, transaction: UnconfirmedTransaction) -> BigInt {
        switch server {
        case .xDai:
            //xdai transactions are always 1 gwei in gasPrice
            return GasPriceConfiguration.xDaiGasPrice
        case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .phi, .ioTeX, .ioTeXTestnet:
            let maxPrice: BigInt = GasPriceConfiguration.maxPrice(forServer: server)
            let defaultPrice: BigInt = GasPriceConfiguration.defaultPrice(forServer: server)
            if let gasPrice = transaction.gasPrice, gasPrice > 0 {
                return min(max(gasPrice, GasPriceConfiguration.minPrice), maxPrice)
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
            GasEstimates(standard: BigInt(estimates.standard), others: [
                TransactionConfigurationType.slow: BigInt(estimates.slow),
                TransactionConfigurationType.fast: BigInt(estimates.fast),
                TransactionConfigurationType.rapid: BigInt(estimates.rapid)
            ])
        }
    }

    private func estimateGasPriceForXDai() -> Promise<GasEstimates> {
        //xDAI node returns a much higher gas price than necessary so if it is xDAI simply return 1 Gwei
        .value(.init(standard: GasPriceConfiguration.xDaiGasPrice))
    }

    private func estimateGasPriceForUseRpcNode(server: RPCServer) -> Promise<GasEstimates> {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(GasPriceRequest()))
        let maxPrice: BigInt = GasPriceConfiguration.maxPrice(forServer: server)
        let defaultPrice: BigInt = GasPriceConfiguration.defaultPrice(forServer: server)

        return firstly {
            Session.send(request, server: server, analytics: analytics)
        }.get { estimate in
            infoLog("Estimated gas price with RPC node server: \(server) estimate: \(estimate)")
        }.map {
            if let gasPrice = BigInt($0.drop0x, radix: 16) {
                if (gasPrice + GasPriceConfiguration.oneGwei) > maxPrice {
                    // Guard against really high prices
                    return GasEstimates(standard: maxPrice)
                } else {
                    if server.canUserChangeGas && server.shouldAddBufferWhenEstimatingGasPrice {
                        //Add an extra gwei because the estimate is sometimes too low
                        return GasEstimates(standard: gasPrice + GasPriceConfiguration.oneGwei)
                    } else {
                        return GasEstimates(standard: gasPrice)
                    }
                }
            } else {
                return GasEstimates(standard: defaultPrice)
            }
        }.recover { _ -> Promise<GasEstimates> in
            .value(GasEstimates(standard: defaultPrice))
        }
    }
}
