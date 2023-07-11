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

    private let function = GetIsERC875()

    public let contract: AlphaWallet.Address
    public var name: String { function.name }
    public var abi: String { function.abi }

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
