//
//  Erc20NameMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletWeb3

struct Erc20NameMethodCall: ContractMethodCall {
    typealias Response = String

    let contract: AlphaWallet.Address
    let name: String = "name"
    let abi: String = Web3.Utils.erc20ABI

    init(contract: AlphaWallet.Address) {
        self.contract = contract
    }

    func response(from dictionary: [String: Any]) throws -> String {
        guard let name = dictionary["0"] as? String else {
            throw CastError(actualValue: dictionary["0"], expectedType: String.self)
        }
        return name
    }
}
