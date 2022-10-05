//
//  Promise+Web3+Eth+GetTransactionCount.swift
//  web3swift
//
//  Created by Alexander Vlasov on 17.06.2018.
//  Copyright © 2018 Bankex Foundation. All rights reserved.
//

import Foundation
import BigInt
import PromiseKit

extension Web3.Eth {
    public func getTransactionCountPromise(address: EthereumAddress, onBlock: String = "latest") -> Promise<BigUInt> {
        let addr = address.address
        return getTransactionCountPromise(address: addr, onBlock: onBlock)
    }
    
    public func getTransactionCountPromise(address: String, onBlock: String = "latest") -> Promise<BigUInt> {
        let request = JSONRPCrequest(method: .getTransactionCount, params: JSONRPCparams(params: [address.lowercased(), onBlock]))
        let rp = web3.dispatch(request)
        return rp.map(on: web3.queue) { response in
            guard let value: BigUInt = response.getValue() else {
                if response.error != nil {
                    throw Web3Error.nodeError(response.error!.message)
                }
                throw Web3Error.nodeError("Invalid value from Ethereum node")
            }
            return value
        }
    }
}
