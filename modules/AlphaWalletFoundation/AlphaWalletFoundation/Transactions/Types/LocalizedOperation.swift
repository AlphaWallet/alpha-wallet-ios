// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public struct LocalizedOperation: Equatable, Hashable {
    //TODO good to have getters/setter computed properties for `from` and `to` too that is typed AlphaWallet.Address. But have to be careful and check if they can be empty or "0x"
    public var from: String = ""
    public var to: String = ""
    public var contract: String? = .none
    public var type: String = ""
    public var value: String = ""
    public var tokenId: String = ""
    public var name: String? = .none
    public var symbol: String? = .none
    public var decimals: Int = 18

    init(object: LocalizedOperationObject) {
        self.from = object.from
        self.to = object.to
        self.contract = object.contract
        self.type = object.type
        self.value = object.value
        self.tokenId = object.tokenId
        self.symbol = object.symbol
        self.name = object.name
        self.decimals = object.decimals
    }

    public init(from: String,
                to: String,
                contract: AlphaWallet.Address?,
                type: String,
                value: String,
                tokenId: String,
                symbol: String?,
                name: String?,
                decimals: Int) {

        self.from = from
        self.to = to
        self.contract = contract?.eip55String
        self.type = type
        self.value = value
        self.tokenId = tokenId
        self.symbol = symbol
        self.name = name
        self.decimals = decimals
    }

    public var operationType: OperationType {
        return OperationType(string: type)
    }

    public var contractAddress: AlphaWallet.Address? {
        return contract.flatMap { AlphaWallet.Address(uncheckedAgainstNullAddress: $0) }
    }

    public func isSend(from: AlphaWallet.Address) -> Bool {
        guard operationType.isTransfer else { return false }
        return from.sameContract(as: self.from)
    }

    public func isReceived(by to: AlphaWallet.Address) -> Bool {
        guard operationType.isTransfer else { return false }
        return to.sameContract(as: self.to)
    }

    public static func == (lhs: LocalizedOperation, rhs: LocalizedOperation) -> Bool {
        return lhs.from == rhs.from &&
            lhs.to == rhs.to &&
            lhs.contract == rhs.contract &&
            lhs.type == rhs.type &&
            lhs.value == rhs.value &&
            lhs.symbol == rhs.symbol &&
            lhs.name == rhs.name &&
            lhs.decimals == rhs.decimals
    }
}
