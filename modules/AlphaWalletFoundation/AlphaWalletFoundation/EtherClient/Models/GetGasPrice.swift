//
//  GetGasPrice.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.08.2022.
//

import Foundation
import BigInt
import APIKit
import JSONRPCKit
import Combine
import AlphaWalletCore

public typealias APIKitSession = APIKit.Session
public typealias SessionTaskError = APIKit.SessionTaskError
public typealias JSONRPCError = JSONRPCKit.JSONRPCError

extension SessionTaskError {
    public var unwrapped: Error {
        switch self {
        case .connectionError(let e):
            return e
        case .requestError(let e):
            return e
        case .responseError(let e):
            return e
        }
    }
}

public final class GetGasPrice {
    private let analytics: AnalyticsLogger
    private let server: RPCServer

    public init(server: RPCServer, analytics: AnalyticsLogger) {
        self.server = server
        self.analytics = analytics
    }

    public func getGasEstimates() -> AnyPublisher<GasEstimates, PromiseError> {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(GasPriceRequest()))
        let maxPrice: BigUInt = GasPriceConfiguration.maxPrice(forServer: server)
        let defaultPrice: BigUInt = GasPriceConfiguration.defaultPrice(forServer: server)

        return APIKitSession
            .sendPublisher(request, server: server, analytics: analytics)
            .handleEvents(receiveOutput: { [server] estimate in
                infoLog("Estimated gas price with RPC node server: \(server) estimate: \(estimate)")
            }).map { [server] gasPrice in
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
            }.catch { _ -> AnyPublisher<GasEstimates, PromiseError> in .just(GasEstimates(standard: defaultPrice)) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}
