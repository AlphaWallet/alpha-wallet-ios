//
//  AnyContractMethod.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.11.2022.
//

import Foundation
import AlphaWalletWeb3

public struct AnyContractMethod: ContractMethod {
    let method: String
    let abi: String
    let params: [AnyObject]

    public init(method: String, abi: String, params: [AnyObject]) {
        self.method = method
        self.abi = abi
        self.params = params
    }

    public func encodedABI() throws -> Data {
        let contract = try ContractV2(abi: abi, address: nil)
        let transaction = try contract.method(method, parameters: params, options: nil)

        return transaction.data
    }
}
