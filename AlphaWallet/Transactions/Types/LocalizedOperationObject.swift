// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift

class LocalizedOperationObject: Object {
    //TODO good to have getters/setter computed properties for `from` and `to` too that is typed AlphaWallet.Address. But have to be careful and check if they can be empty or "0x"
    @objc dynamic var from: String = ""
    @objc dynamic var to: String = ""
    @objc dynamic var contract: String? = .none
    @objc dynamic var type: String = ""
    @objc dynamic var value: String = ""
    @objc dynamic var name: String? = .none
    @objc dynamic var symbol: String? = .none
    @objc dynamic var decimals: Int = 18

    convenience init(
        from: String,
        to: String,
        contract: AlphaWallet.Address?,
        type: String,
        value: String,
        symbol: String?,
        name: String?,
        decimals: Int
    ) {
        self.init()
        self.from = from
        self.to = to
        self.contract = contract?.eip55String
        self.type = type
        self.value = value
        self.symbol = symbol
        self.name = name
        self.decimals = decimals
    }

    var operationType: OperationType {
        return OperationType(string: type)
    }

    var contractAddress: AlphaWallet.Address? {
        return contract.flatMap { AlphaWallet.Address(uncheckedAgainstNullAddress: $0) }
    }
}