//
//  Web3+Instance.swift
//  web3swift
//
//  Created by Alexander Vlasov on 19.12.2017.
//  Copyright © 2017 Bankex Foundation. All rights reserved.
//

import Foundation
import BigInt
import PromiseKit

public enum Web3Error: Error {
    case connectionError(Error)
    case responseError(Error)
    case inputError(String)
    case nodeError(String)
    case generalError(Error)
    case rateLimited
}

public typealias RPCNodeHTTPHeaders = [String: String]

public class Web3: Web3OptionsInheritable {
    public let options: Web3Options = Web3Options.defaultOptions()
    public let queue: DispatchQueue
    public let chainID: BigUInt
    private let provider: Web3RequestProvider
    private let requestDispatcher: JSONRPCrequestDispatcher

    public func dispatch(_ request: JSONRPCrequest) -> Promise<JSONRPCresponse> {
        return requestDispatcher.addToQueue(request: request)
    }

    public init(provider: Web3RequestProvider, chainID: BigUInt, queue: OperationQueue? = nil, requestDispatcher: JSONRPCrequestDispatcher? = nil) {
        self.provider = provider
        self.chainID = chainID
        let operationQueue: OperationQueue
        if queue == nil {
            operationQueue = OperationQueue.init()
            operationQueue.maxConcurrentOperationCount = 32
            operationQueue.underlyingQueue = DispatchQueue.global(qos: .userInteractive)
        } else {
            operationQueue = queue!
        }
        self.queue = operationQueue.underlyingQueue!
        if requestDispatcher == nil {
            self.requestDispatcher = JSONRPCrequestDispatcher(provider: provider, queue: self.queue, policy: .Batch(32))
        } else {
            self.requestDispatcher = requestDispatcher!
        }
    }

    public class Eth: Web3OptionsInheritable {
        public let web3: Web3
        public var options: Web3Options {
            return self.web3.options
        }

        public init(web3: Web3) {
            self.web3 = web3
        }
    }

    public class Personal: Web3OptionsInheritable {
        public let web3: Web3
        public var options: Web3Options {
            return web3.options
        }

        public init(web3: Web3) {
            self.web3 = web3
        }
    } 
}
