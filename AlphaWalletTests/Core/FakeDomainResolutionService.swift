// Copyright © 2022 Stormbird PTE. LTD.

@testable import AlphaWallet
import Foundation
import PromiseKit

class FakeDomainResolutionService: DomainResolutionServiceType {
    func resolveAddress(string value: String) -> Promise<BlockieAndAddressOrEnsResolution> {
        return Promise { _ in }
    }

    func resolveEns(address: AlphaWallet.Address) -> Promise<BlockieAndAddressOrEnsResolution> {
        return Promise { _ in }
    }
}