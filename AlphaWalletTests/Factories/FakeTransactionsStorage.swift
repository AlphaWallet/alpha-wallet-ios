// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
import AlphaWalletFoundation
import Foundation

class FakeTransactionsStorage: TransactionDataStore {
    convenience init(wallet: Wallet = .init(address: Constants.nativeCryptoAddressInDatabase, origin: .hd)) {
        self.init(store: .fake(for: wallet))
    }
}
