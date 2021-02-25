// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit

struct InsufficientFundsError: LocalizedError {
    var errorDescription: String? {
        R.string.localizable.configureTransactionNotEnoughFunds()
    }
}

struct PossibleBinanceTestnetTimeoutError: LocalizedError {
}

extension Session {
    class func send<Request: APIKit.Request>(_ request: Request, callbackQueue: CallbackQueue? = nil) -> Promise<Request.Response> {
        Promise { seal in
            Session.send(request, callbackQueue: callbackQueue) { result in
                switch result {
                case .success(let result):
                    seal.fulfill(result)
                case .failure(let error):
                    if case let .responseError(JSONRPCError.responseError(_, message: message, _)) = error {
                        if message.lowercased().hasPrefix("insufficient funds") {
                            seal.reject(InsufficientFundsError())
                            return
                        } else {
                            //no-op
                        }
                    }
                    if case let SessionTaskError.responseError(e) = error, RPCServer.binance_smart_chain_testnet.rpcURL.absoluteString == request.baseURL.absoluteString, e.localizedDescription == "The data couldn’t be read because it isn’t in the correct format." {
                        //This is potentially Binance testnet timing out
                        seal.reject(PossibleBinanceTestnetTimeoutError())
                        return
                    }
                    seal.reject(error)
                }
            }
        }
    }
}