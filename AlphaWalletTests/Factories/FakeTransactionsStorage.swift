// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

class FakeTransactionsStorage: TransactionDataStore {
    convenience init(wallet: Wallet = .init(type: .watch(Constants.nativeCryptoAddressInDatabase))) {
        let store = FakeRealmLocalStore()
        self.init(store: store.getOrCreateStore(forWallet: wallet))
    }
}
