//
//  AddressOrEnsResolution.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.01.2022.
//

import Foundation
import AlphaWalletCore

public enum AddressOrDomainNameResolution {
    case invalidInput
    case resolved(AddressOrDomainName?)

    public var value: String? {
        switch self {
        case .invalidInput:
            return nil
        case .resolved(let optional):
            return optional?.stringValue
        }
    }
}

public typealias BlockieAndAddressOrEnsResolution = (image: BlockiesImage?, resolution: AddressOrDomainNameResolution)
