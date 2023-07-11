// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress

public enum AddressOrDomainName: Equatable {
    case address(AlphaWallet.Address)
    case domainName(String)

    public init(address: AlphaWallet.Address) {
        self = .address(address)
    }

    public init?(domainName: String) {
        let optionalResult: AddressOrDomainName?
        if domainName.contains(".") {
            optionalResult = .domainName(domainName)
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
        let optionalResult: AddressOrDomainName?
        if let address = AlphaWallet.Address(string: string) {
            optionalResult = .address(address)
        } else {
            optionalResult = AddressOrDomainName(domainName: string)
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
        case .domainName(let string):
            return string
        }
    }

    public var contract: AlphaWallet.Address? {
        switch self {
        case .address(let address):
            return address
        case .domainName:
            return nil
        }
    }

    //TODO reduce usage
    public func sameContract(as contract: String) -> Bool {
        switch self {
        case .address(let address):
            return address.eip55String.drop0x.lowercased() == contract.drop0x.lowercased()
        case .domainName:
            return false
        }
    }
}
