//
//  AnyContractMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation

struct AnyContractMethodCall: ContractMethodCall {
    typealias Response = [String: Any]

    let contract: AlphaWallet.Address
    let name: String
    let abi: String
    let parameters: [AnyObject]

    init(contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject]) {
        self.contract = contract
        self.name = functionName
        self.abi = abiString
        self.parameters = parameters
    }

    func response(from dictionary: [String: Any]) throws -> [String: Any] {
        return dictionary
    }
}
