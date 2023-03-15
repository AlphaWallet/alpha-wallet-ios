//
//  Erc875BalanceOfMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 20.01.2023.
//

import Foundation

struct Erc875BalanceOfMethodCall: ContractMethodCall {
    typealias Response = [String]

    private let function = GetERC875Balance()
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
        return Erc875BalanceOfMethodCall.adapt(dictionary["0"])
    }

    private static func adapt(_ values: Any?) -> [String] {
        guard let array = values as? [Data] else { return [] }
        return array.map { each in
            let value = each.toHexString()
            return "0x\(value)"
        }
    }
}
