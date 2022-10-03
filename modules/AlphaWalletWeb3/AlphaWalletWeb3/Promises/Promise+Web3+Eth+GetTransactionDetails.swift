//
//  Promise+Web3+Eth+GetTransactionDetails.swift
//  web3swift
//
//  Created by Alexander Vlasov on 17.06.2018.
//  Copyright © 2018 Bankex Foundation. All rights reserved.
//

import Foundation
import BigInt
import PromiseKit

extension Web3.Eth {
    public func getTransactionDetailsPromise(_ txhash: Data) -> Promise<TransactionDetails> {
        let hashString = txhash.toHexString().addHexPrefix()
        return self.getTransactionDetailsPromise(hashString)
    }
    
    public func getTransactionDetailsPromise(_ txhash: String) -> Promise<TransactionDetails> {
        let request = JSONRPCrequest(method: .getTransactionByHash, params: JSONRPCparams(params: [txhash]))
        let rp = web3.dispatch(request)
        return rp.map(on: web3.queue) { response in
            guard let value: TransactionDetails = response.getValue() else {
                if response.error != nil {
                    throw Web3Error.nodeError(response.error!.message)
                }
                throw Web3Error.nodeError("Invalid value from Ethereum node")
            }
            return value
        }
    }
}
