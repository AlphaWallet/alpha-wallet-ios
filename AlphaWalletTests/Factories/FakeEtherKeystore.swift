// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
@testable import AlphaWallet
import KeychainSwift

class FakeEtherKeystore: EtherKeystore {
    convenience init() {
        let uniqueString = NSUUID().uuidString
        try! self.init(keychain: KeychainSwift(keyPrefix: "fake" + uniqueString), userDefaults: UserDefaults.test, analyticsCoordinator: FakeAnalyticsService())
    }
}
