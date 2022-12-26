// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit

public class IsErc875Contract {
    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    public func getIsERC875Contract(for contract: AlphaWallet.Address) -> Promise<Bool> {
        blockchainProvider
            .callPromise(Erc875IsStormBirdContractRequest(contract: contract))
            .get {
                print("xxx.Erc876 isStormBirdContract value: \($0)")
            }.recover { e -> Promise<Bool> in
                print("xxx.Erc876 isStormBirdContract failure: \(e)")
                throw e
            }
    }
}

struct Erc875IsStormBirdContractRequest: ContractMethodCall {
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
