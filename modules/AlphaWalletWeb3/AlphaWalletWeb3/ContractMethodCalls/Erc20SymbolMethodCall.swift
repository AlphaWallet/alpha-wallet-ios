//
//  Erc20SymbolMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletAddress
import AlphaWalletCore

public struct Erc20SymbolMethodCall: ContractMethodCall {
    public typealias Response = String

    public let contract: AlphaWallet.Address
    public let name: String = "symbol"
    public let abi: String = Web3.Utils.erc20ABI

    public init(contract: AlphaWallet.Address) {
        self.contract = contract
    }

    public func response(from dictionary: [String: Any]) throws -> String {
        guard let name = dictionary["0"] as? String else {
            throw CastError(actualValue: dictionary["0"], expectedType: String.self)
        }
        return name
    }
}
