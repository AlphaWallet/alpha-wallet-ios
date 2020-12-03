// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import APIKit
import PromiseKit

extension Session {
    class func send<Request: APIKit.Request>(_ request: Request, callbackQueue: CallbackQueue? = nil) -> Promise<Request.Response> {
        Promise { seal in
            Session.send(request, callbackQueue: callbackQueue) { result in
                switch result {
                case .success(let result):
                    seal.fulfill(result)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }
}