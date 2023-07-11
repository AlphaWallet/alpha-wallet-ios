// Copyright © 2022 Stormbird PTE. LTD.

@testable import AlphaWallet
import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletFoundation

class FakeDomainResolutionService: DomainNameResolutionServiceType {
    func resolveAddress(string value: String) -> AnyPublisher<AlphaWallet.Address, PromiseError> {
        return Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    func reverseResolveDomainName(address: AlphaWallet.Address, server: AlphaWalletFoundation.RPCServer) -> AnyPublisher<DomainName, PromiseError> {
        return Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    func resolveEnsAndBlockie(address: AlphaWallet.Address, server: AlphaWalletFoundation.RPCServer) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> {
        return Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    func resolveAddressAndBlockie(string: String) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> {
        return Empty(completeImmediately: true).eraseToAnyPublisher()
    }
}
