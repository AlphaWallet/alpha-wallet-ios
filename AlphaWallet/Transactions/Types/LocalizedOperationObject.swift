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

    convenience init(object: LocalizedOperationObjectInstance) {
        self.init()
        self.from = object.from
        self.to = object.to
        self.contract = object.contract
        self.type = object.type
        self.value = object.value
        self.symbol = object.symbol
        self.name = object.name
        self.decimals = object.decimals
    }

    var operationType: OperationType {
        return OperationType(string: type)
    }

    var contractAddress: AlphaWallet.Address? {
        return contract.flatMap { AlphaWallet.Address(uncheckedAgainstNullAddress: $0) }
    }
}

extension LocalizedOperationObject {
    static func from(operations: [LocalizedOperation]?) -> [LocalizedOperationObject] {
        guard let operations = operations else { return [] }
        return operations.compactMap { operation in
            guard let from = operation.fromAddress, let to = operation.toAddress else { return nil }
            return LocalizedOperationObject(
                from: from.description,
                to: to.description,
                contract: operation.contract.contractAddress,
                type: operation.type.rawValue,
                value: operation.value,
                symbol: operation.contract.symbol,
                name: operation.contract.name,
                decimals: operation.contract.decimals
            )
        }
    }
}

struct LocalizedOperationObjectInstance {
    //TODO good to have getters/setter computed properties for `from` and `to` too that is typed AlphaWallet.Address. But have to be careful and check if they can be empty or "0x"
    var from: String = ""
    var to: String = ""
    var contract: String? = .none
    var type: String = ""
    var value: String = ""
    var name: String? = .none
    var symbol: String? = .none
    var decimals: Int = 18

    init(object: LocalizedOperationObject) {
        self.from = object.from
        self.to = object.to
        self.contract = object.contract
        self.type = object.type
        self.value = object.value
        self.symbol = object.symbol
        self.name = object.name
        self.decimals = object.decimals
    }

    init(
        from: String,
        to: String,
        contract: AlphaWallet.Address?,
        type: String,
        value: String,
        symbol: String?,
        name: String?,
        decimals: Int
    ) {
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
