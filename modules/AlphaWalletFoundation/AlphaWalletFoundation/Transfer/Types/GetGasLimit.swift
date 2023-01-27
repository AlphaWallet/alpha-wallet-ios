//
//  GetGasLimit.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2022.
//

import Foundation
import AlphaWalletLogger
import APIKit
import BigInt
import JSONRPCKit
import PromiseKit

final class GetGasLimit {
    private let server: RPCServer
    private let analytics: AnalyticsLogger

    init(server: RPCServer, analytics: AnalyticsLogger) {
        self.server = server
        self.analytics = analytics
    }

    func getGasLimit(account: AlphaWallet.Address, value: BigUInt, transactionType: EstimateGasTransactionType, data: Data) -> Promise<BigUInt> {
        let request = EstimateGasRequest(from: account, transactionType: transactionType, value: value, data: data)

        return firstly {
            APIKitSession.send(EtherServiceRequest(server: server, batch: BatchFactory().create(request)), server: server, analytics: analytics)
        }.map { gasLimit -> BigUInt in
            infoLog("[Gas] Estimated gas limit with eth_estimateGas: \(gasLimit)")
            return gasLimit
        }
    }
}
