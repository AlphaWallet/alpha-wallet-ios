// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import Combine

//Use the wallet name which the user has set, otherwise fallback to ENS, if available
class GetWalletName {
    private let domainResolutionService: DomainResolutionServiceType

    init(domainResolutionService: DomainResolutionServiceType) {
        self.domainResolutionService = domainResolutionService
    }

    func assignedNameOrEns(for address: AlphaWallet.Address) -> AnyPublisher<String?, Never> {
        //TODO: pass ref
        if let walletName = FileWalletStorage().name(for: address) {
            return .just(walletName)
        } else {
            return domainResolutionService.resolveEns(address: address)
                .map { ens -> EnsName? in return ens }
                .replaceError(with: nil)
                .eraseToAnyPublisher()
        }
    }
}
