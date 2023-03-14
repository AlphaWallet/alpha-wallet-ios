//
//  Erc20DecimalsMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletWeb3

struct Erc20DecimalsMethodCall: ContractMethodCall {
    typealias Response = Int

    let contract: AlphaWallet.Address
    var name: String = "decimals"
    var abi: String = Web3.Utils.erc20ABI
    var parameters: [AnyObject] { [] }

    init(contract: AlphaWallet.Address) {
        self.contract = contract
    }

    func response(from dictionary: [String: Any]) throws -> Int {
        guard let decimalsOfUnknownType = dictionary["0"], let decimals = Int(String(describing: decimalsOfUnknownType)) else {
            throw CastError(actualValue: dictionary["0"], expectedType: Int.self)
        }

        return decimals
    }
}
