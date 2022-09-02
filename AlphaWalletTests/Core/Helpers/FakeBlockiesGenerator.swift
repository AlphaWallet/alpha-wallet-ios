// Copyright © 2022 Stormbird PTE. LTD.

@testable import AlphaWallet
import Foundation
import AlphaWalletFoundation

extension BlockiesGenerator {
    //TODO do we need to make a fake one instead?
    static func make() -> BlockiesGenerator {
        let openSea = OpenSea(analytics: FakeAnalyticsService(), queue: .global())
        return BlockiesGenerator(openSea: openSea, storage: FakeEnsRecordsStorage())
    }
}
