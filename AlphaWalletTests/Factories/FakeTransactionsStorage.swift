// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import AlphaWalletFoundation

class FakeTransactionsStorage: TransactionDataStore {
    convenience init(wallet: Wallet = .init(address: Constants.nativeCryptoAddressInDatabase, origin: .hd)) {
        self.init(store: .fake(for: wallet))
    }
}
