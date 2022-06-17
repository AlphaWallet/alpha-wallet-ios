// Copyright © 2022 Stormbird PTE. LTD.

@testable import AlphaWallet
import Foundation
import Combine

class FakeDomainResolutionService: DomainResolutionServiceType {
    struct E: Error {}

    func resolveAddress(string value: String) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> {
        return Fail(error: PromiseError.some(error: E())).eraseToAnyPublisher()
    }

    func resolveEns(address: AlphaWallet.Address) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> {
        return Fail(error: PromiseError.some(error: E())).eraseToAnyPublisher()
    }
}
