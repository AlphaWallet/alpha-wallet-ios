//
//  Erc721BalanceOfMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletWeb3
import BigInt

struct Erc721BalanceOfMethodCall: ContractMethodCall {
    typealias Response = [String]

    private let function = GetERC721Balance()
    private let address: AlphaWallet.Address

    let contract: AlphaWallet.Address
    var name: String { function.name }
    var abi: String { function.abi }
    var parameters: [AnyObject] { [address.eip55String] as [AnyObject] }

    init(contract: AlphaWallet.Address, address: AlphaWallet.Address) {
        self.address = address
        self.contract = contract
    }

    func response(from dictionary: [String: Any]) throws -> [String] {
        let balance = Erc721BalanceOfMethodCall.adapt(dictionary["0"] as Any)
        if balance >= Int.max {
            throw CastError(actualValue: dictionary["0"], expectedType: Int.self)
        } else {
            return [String](repeating: "0", count: Int(balance))
        }
    }

    private static func adapt(_ value: Any) -> BigUInt {
        if let value = value as? BigUInt {
            return value
        } else {
            return BigUInt(0)
        }
    }
}
