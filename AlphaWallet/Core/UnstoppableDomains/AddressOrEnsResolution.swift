//
//  AddressOrEnsResolution.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.01.2022.
//

import Foundation
import Combine

enum AddressOrEnsResolution {
    case invalidInput
    case resolved(AddressOrEnsName?)

    var value: String? {
        switch self {
        case .invalidInput:
            return nil
        case .resolved(let optional):
            return optional?.stringValue
        }
    }
}

typealias BlockieAndAddressOrEnsResolution = (image: BlockiesImage?, resolution: AddressOrEnsResolution)

protocol DomainResolutionServiceType {
    func resolveAddress(string value: String) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError>
    func resolveEns(address: AlphaWallet.Address) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError>
}

protocol CachebleAddressResolutionServiceType {
    func cachedAddressValue(forName name: String) -> AlphaWallet.Address?
}

protocol CachedEnsResolutionServiceType {
    func cachedEnsValue(forAddress address: AlphaWallet.Address) -> String?
}

struct ENSLookupKey: Hashable {
    let nameOrAddress: String
    let server: RPCServer

    init(nameOrAddress: String, server: RPCServer) {
        //Lowercase for case-insensitive lookups
        self.nameOrAddress = nameOrAddress.lowercased()
        self.server = server
    }
}
