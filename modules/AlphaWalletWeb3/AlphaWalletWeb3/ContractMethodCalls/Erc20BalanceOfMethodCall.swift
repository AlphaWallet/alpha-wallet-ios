//
//  Erc20BalanceOfMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletAddress
import AlphaWalletCore
import BigInt

public struct Erc20BalanceOfMethodCall: ContractMethodCall {
    public typealias Response = BigUInt

    public let contract: AlphaWallet.Address
    public let name: String = "balanceOf"
    public let abi: String = Web3.Utils.erc20ABI
    public var parameters: [AnyObject] { [address.eip55String] as [AnyObject] }

    private let address: AlphaWallet.Address

    public init(contract: AlphaWallet.Address, address: AlphaWallet.Address) {
        self.contract = contract
        self.address = address
    }

    public func response(from dictionary: [String: Any]) throws -> BigUInt {
        guard let balanceOfUnknownType = dictionary["0"], let balance = BigUInt(String(describing: balanceOfUnknownType)) else {
            throw CastError(actualValue: dictionary["0"], expectedType: BigUInt.self)
        }
        return balance
    }
}
