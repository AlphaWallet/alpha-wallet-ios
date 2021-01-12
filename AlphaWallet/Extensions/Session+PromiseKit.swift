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

extension Session {
    class func send<Request: APIKit.Request>(_ request: Request, callbackQueue: CallbackQueue? = nil) -> Promise<Request.Response> {
        Promise { seal in
            Session.send(request, callbackQueue: callbackQueue) { result in
                switch result {
                case .success(let result):
                    seal.fulfill(result)
                case .failure(let error):
                    if case let .responseError(JSONRPCError.responseError(e)) = error {
                        if e.message.hasPrefix("Insufficient funds") {
                            seal.reject(InsufficientFundsError())
                            return
                        } else {
                            //no-op
                        }
                    }
                    seal.reject(error)
                }
            }
        }
    }
}