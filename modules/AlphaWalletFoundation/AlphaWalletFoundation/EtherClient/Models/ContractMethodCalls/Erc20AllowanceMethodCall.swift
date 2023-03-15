//
//  Erc20AllowanceMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletWeb3
import BigInt

struct Erc20AllowanceMethodCall: ContractMethodCall {
    typealias Response = BigUInt

    let owner: AlphaWallet.Address
    let spender: AlphaWallet.Address
    let contract: AlphaWallet.Address
    let name: String = "allowance"
    let abi: String = Web3.Utils.erc20ABI
    var parameters: [AnyObject] { [owner.eip55String, spender.eip55String] as [AnyObject] }

    init(contract: AlphaWallet.Address, owner: AlphaWallet.Address, spender: AlphaWallet.Address) {
        self.contract = contract
        self.owner = owner
        self.spender = spender
    }

    func response(from dictionary: [String: Any]) throws -> BigUInt {
        guard let allowance = dictionary["0"] as? BigUInt else {
            throw CastError.init(actualValue: dictionary["0"], expectedType: BigUInt.self)
        }

        return allowance
    }
}
