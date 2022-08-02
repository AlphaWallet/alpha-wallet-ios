// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

class FakeTransactionsStorage: TransactionDataStore {
    convenience init(wallet: Wallet = .init(address: Constants.nativeCryptoAddressInDatabase, origin: .hd)) {
        let store = FakeRealmLocalStore()
        self.init(store: store.getOrCreateStore(forWallet: wallet))
    }
}
