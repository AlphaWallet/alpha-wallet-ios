// Copyright © 2022 Stormbird PTE. LTD.

@testable import AlphaWallet
import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletFoundation

class FakeDomainResolutionService: DomainResolutionServiceType {
    func resolveAddress(string value: String) -> AnyPublisher<AlphaWallet.Address, PromiseError> {
        return Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    func resolveEns(address: AlphaWallet.Address) -> AnyPublisher<EnsName, PromiseError> {
        return Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    func resolveEnsAndBlockie(address: AlphaWallet.Address) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> {
        return Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    func resolveAddressAndBlockie(string: String) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> {
        return Empty(completeImmediately: true).eraseToAnyPublisher()
    }
}
