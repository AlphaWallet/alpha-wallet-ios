//
//  GetGasPrice.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.08.2022.
//

import Foundation
import PromiseKit
import BigInt
import APIKit
import JSONRPCKit

public typealias SessionTaskError = APIKit.SessionTaskError
public typealias JSONRPCError = JSONRPCKit.JSONRPCError

public final class GetGasPrice {
    private let analytics: AnalyticsLogger
    private let server: RPCServer

    public init(server: RPCServer, analytics: AnalyticsLogger) {
        self.server = server
        self.analytics = analytics
    }

    public func getGasEstimates() -> Promise<GasEstimates> {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(GasPriceRequest()))
        let maxPrice: BigInt = GasPriceConfiguration.maxPrice(forServer: server)
        let defaultPrice: BigInt = GasPriceConfiguration.defaultPrice(forServer: server)

        return firstly {
            Session.send(request, server: server, analytics: analytics)
        }.get { [server] estimate in
            infoLog("Estimated gas price with RPC node server: \(server) estimate: \(estimate)")
        }.map { [server] in
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

public final class EthCall {
    private let server: RPCServer
    private let analytics: AnalyticsLogger

    public init(server: RPCServer, analytics: AnalyticsLogger) {
        self.server = server
        self.analytics = analytics
    }

    public func ethCall(from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String) -> Promise<String> {
        let request = EthCallRequest(from: from, to: to, value: value, data: data)
        return Session.send(EtherServiceRequest(server: server, batch: BatchFactory().create(request)), server: server, analytics: analytics)
    }
}
