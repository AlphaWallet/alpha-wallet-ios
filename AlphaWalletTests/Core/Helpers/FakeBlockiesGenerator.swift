// Copyright © 2022 Stormbird PTE. LTD.

@testable import AlphaWallet
import Foundation
import AlphaWalletFoundation

extension BlockiesGenerator {
    //TODO do we need to make a fake one instead?
    static func make() -> BlockiesGenerator {
        let provider = BlockchainsProvider.make(servers: [.main])
        return BlockiesGenerator(
            assetImageProvider: FakeNftProvider(),
            storage: FakeEnsRecordsStorage(),
            blockchainProvider: provider.blockchain(with: .main)!)
    }
}
