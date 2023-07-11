//
//  Erc20AllowanceMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletAddress
import AlphaWalletCore
import BigInt

public struct Erc20AllowanceMethodCall: ContractMethodCall {
    public typealias Response = BigUInt

    let owner: AlphaWallet.Address
    let spender: AlphaWallet.Address
    public let contract: AlphaWallet.Address
    public let name: String = "allowance"
    public let abi: String = Web3.Utils.erc20ABI
    public var parameters: [AnyObject] { [owner.eip55String, spender.eip55String] as [AnyObject] }

    public init(contract: AlphaWallet.Address, owner: AlphaWallet.Address, spender: AlphaWallet.Address) {
        self.contract = contract
        self.owner = owner
        self.spender = spender
    }

    public func response(from dictionary: [String: Any]) throws -> BigUInt {
        guard let allowance = dictionary["0"] as? BigUInt else {
            throw CastError.init(actualValue: dictionary["0"], expectedType: BigUInt.self)
        }

        return allowance
    }
}
