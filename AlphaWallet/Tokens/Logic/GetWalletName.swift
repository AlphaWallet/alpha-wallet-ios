// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import Combine

//Use the wallet name which the user has set, otherwise fallback to ENS, if available
class GetWalletName {
    private let config: Config
    private let domainResolutionService: DomainResolutionServiceType

    init(config: Config, domainResolutionService: DomainResolutionServiceType) {
        self.config = config
        self.domainResolutionService = domainResolutionService
    }

    func getName(for address: AlphaWallet.Address) -> AnyPublisher<String, PromiseError> {
        struct ResolveEnsError: Error {}
        if let walletName = config.walletNames[address] {
            return Just(walletName).setFailureType(to: PromiseError.self).eraseToAnyPublisher()
        } else {
            return domainResolutionService.resolveEns(address: address).tryMap { result in
                if let value = result.resolution.value {
                    return value
                } else {
                    throw ResolveEnsError()
                }
            }.mapError { PromiseError.some(error: $0) }.eraseToAnyPublisher()
        }
    }
}
