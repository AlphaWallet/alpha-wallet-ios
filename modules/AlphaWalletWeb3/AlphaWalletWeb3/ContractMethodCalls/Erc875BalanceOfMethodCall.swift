//
//  Erc875BalanceOfMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 20.01.2023.
//

import Foundation
import AlphaWalletAddress

public struct Erc875BalanceOfMethodCall: ContractMethodCall {
    public typealias Response = [String]

    private let address: AlphaWallet.Address

    public let contract: AlphaWallet.Address
    public var name: String { "balanceOf" }
    public var abi: String { AlphaWallet.Ethereum.ABI.erc875 }
    public var parameters: [AnyObject] { [address.eip55String] as [AnyObject] }

    public init(contract: AlphaWallet.Address, address: AlphaWallet.Address) {
        self.address = address
        self.contract = contract
    }

    public func response(from dictionary: [String: Any]) throws -> [String] {
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
