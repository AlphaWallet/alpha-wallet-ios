// Copyright © 2022 Stormbird PTE. LTD.

@testable import AlphaWallet
import Foundation
import AlphaWalletFoundation

extension BlockiesGenerator {
    //TODO do we need to make a fake one instead?
    static func make() -> BlockiesGenerator {
        return BlockiesGenerator(
            assetImageProvider: FakeNftProvider(),
            storage: FakeEnsRecordsStorage(),
            blockchainProvider: RpcBlockchainProvider(server: .main, analytics: FakeAnalyticsService(), params: .defaultParams(for: .main)))
    }
}
