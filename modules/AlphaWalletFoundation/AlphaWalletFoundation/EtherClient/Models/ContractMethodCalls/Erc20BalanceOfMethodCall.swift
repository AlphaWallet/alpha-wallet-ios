//
//  Erc20BalanceOfMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletWeb3
import BigInt

class Erc20BalanceOfMethodCall: ContractMethodCall {
    typealias Response = BigInt

    let contract: AlphaWallet.Address
    let name: String = "balanceOf"
    let abi: String = Web3.Utils.erc20ABI
    var parameters: [AnyObject] { [address.eip55String] as [AnyObject] }

    private let address: AlphaWallet.Address

    init(contract: AlphaWallet.Address, address: AlphaWallet.Address) {
        self.contract = contract
        self.address = address
    }

    func response(from resultObject: Any) throws -> BigInt {
        guard let dictionary = resultObject as? [String: AnyObject] else {
            throw CastError(actualValue: resultObject, expectedType: BigInt.self)
        }

        guard let balanceOfUnknownType = dictionary["0"], let balance = BigInt(String(describing: balanceOfUnknownType)) else {
            throw CastError(actualValue: dictionary["0"], expectedType: BigInt.self)
        }
        return balance
    }
}
