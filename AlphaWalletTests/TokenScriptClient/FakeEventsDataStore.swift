// Copyright © 2020 Stormbird PTE. LTD.

@testable import AlphaWallet
import AlphaWalletFoundation

class FakeEventsDataStore: NonActivityMultiChainEventsDataStore {
    convenience init(account: Wallet = .make()) {
        self.init(store: .fake(for: account))
    }
}
