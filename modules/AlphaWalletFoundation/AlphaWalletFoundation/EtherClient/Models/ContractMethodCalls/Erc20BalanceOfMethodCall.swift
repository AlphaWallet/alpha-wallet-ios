//
//  Erc20BalanceOfMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletWeb3
import BigInt

struct Erc20BalanceOfMethodCall: ContractMethodCall {
    typealias Response = BigUInt

    let contract: AlphaWallet.Address
    let name: String = "balanceOf"
    let abi: String = Web3.Utils.erc20ABI
    var parameters: [AnyObject] { [address.eip55String] as [AnyObject] }

    private let address: AlphaWallet.Address

    init(contract: AlphaWallet.Address, address: AlphaWallet.Address) {
        self.contract = contract
        self.address = address
    }

    func response(from dictionary: [String: Any]) throws -> BigUInt {
        guard let balanceOfUnknownType = dictionary["0"], let balance = BigUInt(String(describing: balanceOfUnknownType)) else {
            throw CastError(actualValue: dictionary["0"], expectedType: BigUInt.self)
        }
        return balance
    }
}
