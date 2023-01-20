//
//  Erc875IsStormBirdContractMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation

struct Erc875IsStormBirdContractMethodCall: ContractMethodCall {
    typealias Response = Bool

    private let function = GetIsERC875()

    let contract: AlphaWallet.Address
    var name: String { function.name }
    var abi: String { function.abi }

    init(contract: AlphaWallet.Address) {
        self.contract = contract
    }

    func response(from resultObject: Any) throws -> Bool {
        guard let dictionary = resultObject as? [String: AnyObject] else {
            throw CastError(actualValue: resultObject, expectedType: [String: AnyObject].self)
        }

        guard let isErc875 = dictionary["0"] as? Bool else {
            throw CastError(actualValue: dictionary["0"], expectedType: Bool.self)
        }
        return isErc875
    }
}
