//
//  Erc20DecimalsMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletAddress
import AlphaWalletCore

public struct Erc20DecimalsMethodCall: ContractMethodCall {
    public typealias Response = Int

    public let contract: AlphaWallet.Address
    public var name: String = "decimals"
    public var abi: String = Web3.Utils.erc20ABI
    public var parameters: [AnyObject] { [] }

    public init(contract: AlphaWallet.Address) {
        self.contract = contract
    }

    public func response(from dictionary: [String: Any]) throws -> Int {
        guard let decimalsOfUnknownType = dictionary["0"], let decimals = Int(String(describing: decimalsOfUnknownType)) else {
            throw CastError(actualValue: dictionary["0"], expectedType: Int.self)
        }

        return decimals
    }
}
