// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

//TODO this should probably be part of AlphaWallet.Address functionality instead, but narrowing the scope of the current change when we added this
public enum AddressOrEnsName {
    case address(AlphaWallet.Address)
    case ensName(String)

    public init(address: AlphaWallet.Address) {
        self = .address(address)
    }

    public init?(ensName: String) {
        let optionalResult: AddressOrEnsName?
        if ensName.contains(".") {
            optionalResult = .ensName(ensName)
        } else {
            optionalResult = nil
        }
        if let result = optionalResult {
            self = result
        } else {
            return nil
        }
    }

    public init?(string: String) {
        let optionalResult: AddressOrEnsName?
        if let address = AlphaWallet.Address(string: string) {
            optionalResult = .address(address)
        } else {
            optionalResult = AddressOrEnsName(ensName: string)
        }
        if let result = optionalResult {
            self = result
        } else {
            return nil
        }
    }

    public var stringValue: String {
        switch self {
        case .address(let address):
            return address.eip55String
        case .ensName(let string):
            return string
        }
    }

    public var contract: AlphaWallet.Address? {
        switch self {
        case .address(let address):
            return address
        case .ensName:
            return nil
        }
    }

    //TODO reduce usage
    public func sameContract(as contract: String) -> Bool {
        switch self {
        case .address(let address):
            return address.eip55String.drop0x.lowercased() == contract.drop0x.lowercased()
        case .ensName:
            return false
        }
    }
}
