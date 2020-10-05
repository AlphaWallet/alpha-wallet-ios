//Copyright © 2018 Stormbird PTE. LTD.

import FBSnapshotTestCase
@testable import AlphaWallet
import UIKit

class EnterSellTokensCardPriceQuantityViewControllerTests: FBSnapshotTestCase {
    override func setUp() {
        super.setUp()
        recordMode = false
    }

    //TODO restore after confirm send/receive buttons
//    func testSellTokensCardPriceQuantityViewControllerDisplay() {
//        let token = Token(id: "1", index: 1, name: "", status: .available, values: ["locality": "", "venue": "", "match": 9, "time": GeneralisedTime(string: "20010203160500+0300")!, "numero": 1, "category": "MATCH CLUB", "countryA": "Team A", "countryB": "Team B"])
//        let tokenHolder = TokenHolder(tokens: [token], contractAddress: "0x1", hasAssetDefinition: true)
//        let tokenObject = TokenObject(contract: "0x0000000000000000000000000000000000000001", name: "", symbol: "", decimals: 0, value: "", isCustom: true, isDisabled: false, type: .erc875)
//        let config = Config()
//        let controller = EnterSellTokensCardPriceQuantityViewController(
//                config: config,
//                storage: FakeTokensDataStore(),
//                paymentFlow: .send(type: .ERC875Token(tokenObject)),
//                cryptoPrice: .init(nil),
//                viewModel: .init(token: tokenObject, tokenHolder: tokenHolder, server: config.server)
//        )
//        controller.configure()
//        controller.pricePerTokenField.ethCost = "0.0000001"

//        FBSnapshotVerifyView(controller.view)
//    }

    //TODO restore when we can run tests with Xcode10 on development machines
//    func testSellTokensCardPriceQuantityViewControllerShowsFiatEquivalentWhenUnitFiatPriceIsMoreThanOneThousand() {
//        let token = Token(id: "1", index: 1, name: "", status: .available, values: ["locality": "", "venue": "", "match": 9, "time": GeneralisedTime(string: "20010203160500+0300")!, "numero": 1, "category": "MATCH CLUB", "countryA": "Team A", "countryB": "Team B"])
//        let tokenHolder = TokenHolder(tokens: [token], contractAddress: "0x1", hasAssetDefinition: true)
//        let tokenObject = TokenObject(contract: "0x0000000000000000000000000000000000000001", name: "", symbol: "", decimals: 0, value: "", isCustom: true, isDisabled: false, type: .erc875)
//        let controller = EnterSellTokensCardPriceQuantityViewController(
//                config: Config(),
//                storage: FakeTokensDataStore(),
//                paymentFlow: .send(type: .ERC875Token(tokenObject)),
//                ethPrice: .init(400),
//                viewModel: .init(token: tokenObject, tokenHolder: tokenHolder)
//        )
//        controller.configure()
//        controller.pricePerTokenField.ethCost = "3"

//        FBSnapshotVerifyView(controller.view)
//    }
}
