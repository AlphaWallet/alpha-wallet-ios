//
//  Erc20SupportsInterfaceMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletAddress
import AlphaWalletCore

public struct Erc20SupportsInterfaceMethodCall: ContractMethodCall {
    public typealias Response = Bool

    private let hash: String

    public let contract: AlphaWallet.Address
    public let name: String = "supportsInterface"
    public var abi: String { AlphaWallet.Ethereum.ABI.erc165 }
    public var parameters: [AnyObject] { [hash] as [AnyObject] }

    public init(contract: AlphaWallet.Address, hash: String) {
        self.contract = contract
        self.hash = hash
    }

    public func response(from dictionary: [String: Any]) throws -> Bool {
        guard let supported = dictionary["0"] as? Bool else {
            throw CastError(actualValue: dictionary["0"], expectedType: Bool.self)
        }

        return supported
    }
}
