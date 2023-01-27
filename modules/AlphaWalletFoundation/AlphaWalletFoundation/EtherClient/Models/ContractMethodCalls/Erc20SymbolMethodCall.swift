//
//  Erc20SymbolMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletWeb3

class Erc20SymbolMethodCall: ContractMethodCall {
    typealias Response = String

    let contract: AlphaWallet.Address
    let name: String = "symbol"
    let abi: String = Web3.Utils.erc20ABI

    init(contract: AlphaWallet.Address) {
        self.contract = contract
    }

    func response(from resultObject: Any) throws -> String {
        guard let dictionary = resultObject as? [String: AnyObject] else {
            throw CastError(actualValue: resultObject, expectedType: [String: AnyObject].self)
        }

        guard let name = dictionary["0"] as? String else {
            throw CastError(actualValue: dictionary["0"], expectedType: String.self)
        }
        return name
    }
}
