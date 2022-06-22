// Copyright © 2022 Stormbird PTE. LTD.

@testable import AlphaWallet
import Foundation
import Combine

class FakeDomainResolutionService: DomainResolutionServiceType {
    struct E: Error {}

    func resolveAddress(string value: String) -> AnyPublisher<AlphaWallet.Address, PromiseError> {
        return .fail(.some(error: E()))
    }

    func resolveEns(address: AlphaWallet.Address) -> AnyPublisher<EnsName, PromiseError> {
        return .fail(.some(error: E()))
    }

    func resolveEnsAndBlockie(address: AlphaWallet.Address) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> {
        return .fail(.some(error: E()))
    }

    func resolveAddressAndBlockie(string: String) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> {
        return .fail(.some(error: E()))
    }
}
