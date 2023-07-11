//
//  Erc721BalanceOfMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletAddress
import AlphaWalletCore
import BigInt

public struct Erc721BalanceOfMethodCall: ContractMethodCall {
    public typealias Response = [String]

    private let function = GetERC721Balance()
    private let address: AlphaWallet.Address

    public let contract: AlphaWallet.Address
    public var name: String { function.name }
    public var abi: String { function.abi }
    public var parameters: [AnyObject] { [address.eip55String] as [AnyObject] }

    public init(contract: AlphaWallet.Address, address: AlphaWallet.Address) {
        self.address = address
        self.contract = contract
    }

    public func response(from dictionary: [String: Any]) throws -> [String] {
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
