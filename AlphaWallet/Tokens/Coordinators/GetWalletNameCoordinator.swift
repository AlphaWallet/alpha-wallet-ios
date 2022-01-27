// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import PromiseKit

//Use the wallet name which the user has set, otherwise fallback to ENS, if available
class GetWalletNameCoordinator {
    private let config: Config
    private let resolver: DomainResolutionServiceType = DomainResolutionService()

    init(config: Config) {
        self.config = config
    }

    func getName(forAddress address: AlphaWallet.Address) -> Promise<String> {
        struct ResolveEnsError: Error {}
        if let walletName = config.walletNames[address] {
            return .value(walletName)
        } else {
            return resolver.resolveEns(address: address).map { result in
                if let value = result.resolution.value {
                    return value
                } else {
                    throw ResolveEnsError()
                }
            }
        }
    }
}
