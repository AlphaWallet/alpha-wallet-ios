// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import PromiseKit

//Use the wallet name which the user has set, otherwise fallback to ENS, if available
class GetWalletNameCoordinator {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func getName(forAddress address: AlphaWallet.Address) -> Promise<String?> {
        Promise { seal in
            if let walletName = config.walletNames[address] {
                seal.fulfill(walletName)
            } else {
                let serverToResolveEns = RPCServer.main
                ENSReverseLookupCoordinator(server: serverToResolveEns).getENSNameFromResolver(forAddress: address) { result in
                    seal.fulfill(result.value)
                }
            }
        }
    }
}
