// Copyright © 2022 Stormbird PTE. LTD.

@testable import AlphaWallet
import Combine
import Foundation
import AlphaWalletCore
import AlphaWalletENS
import AlphaWalletFoundation

//TODO does the results from each stub function work correctly as expected in test suite?:w

class FakeDomainResolutionService: DomainNameResolutionServiceType {
    func resolveAddress(string value: String) async throws -> AlphaWallet.Address {
        return Constants.nullAddress
    }

    func reverseResolveDomainName(address: AlphaWallet.Address, server: AlphaWalletFoundation.RPCServer) async throws -> DomainName {
        struct E: Error {}
        throw E()
    }

    func resolveEnsAndBlockie(address: AlphaWallet.Address, server: AlphaWalletFoundation.RPCServer) async throws -> BlockieAndAddressOrEnsResolution {
        return BlockieAndAddressOrEnsResolution(image: nil, resolution: .invalidInput)
    }

    func resolveAddressAndBlockie(string: String) async throws -> BlockieAndAddressOrEnsResolution {
        return BlockieAndAddressOrEnsResolution(image: nil, resolution: .invalidInput)
    }
}
