//
//  Erc875IsStormBirdContractMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletAddress
import AlphaWalletCore

public struct Erc875IsStormBirdContractMethodCall: ContractMethodCall {
    public typealias Response = Bool

    public let contract: AlphaWallet.Address
    public let name: String = "isStormBirdContract"
    public var abi: String { AlphaWallet.Ethereum.ABI.erc875 }

    public init(contract: AlphaWallet.Address) {
        self.contract = contract
    }

    public func response(from dictionary: [String: Any]) throws -> Bool {
        guard let isErc875 = dictionary["0"] as? Bool else {
            throw CastError(actualValue: dictionary["0"], expectedType: Bool.self)
        }
        return isErc875
    }
}
