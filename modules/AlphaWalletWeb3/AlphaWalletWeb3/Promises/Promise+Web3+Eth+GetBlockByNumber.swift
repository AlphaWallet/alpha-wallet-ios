//
//  Promise+Web3+Eth+GetBlockByNumber.swift
//  web3swift
//
//  Created by Alexander Vlasov on 17.06.2018.
//  Copyright © 2018 Bankex Foundation. All rights reserved.
//

import Foundation
import BigInt
import PromiseKit

extension Web3.Eth {
    public func getBlockByNumberPromise(_ number: UInt64, fullTransactions: Bool = false) -> Promise<Block> {
        let block = String(number, radix: 16).addHexPrefix()
        return getBlockByNumberPromise(block, fullTransactions: fullTransactions)
    }
    
    public func getBlockByNumberPromise(_ number: BigUInt, fullTransactions: Bool = false) -> Promise<Block> {
        let block = String(number, radix: 16).addHexPrefix()
        return getBlockByNumberPromise(block, fullTransactions: fullTransactions)
    }
    
    public func getBlockByNumberPromise(_ number: String, fullTransactions: Bool = false) -> Promise<Block> {
        let request = JSONRPCrequest(method: .getBlockByNumber, params: JSONRPCparams(params: [number, fullTransactions]))
        let rp = web3.dispatch(request)
        return rp.map(on: web3.queue) { response in
            guard let value: Block = response.getValue() else {
                if response.error != nil {
                    throw Web3Error.nodeError(response.error!.message)
                }
                throw Web3Error.nodeError("Invalid value from Ethereum node")
            }
            return value
        }
    }
}
