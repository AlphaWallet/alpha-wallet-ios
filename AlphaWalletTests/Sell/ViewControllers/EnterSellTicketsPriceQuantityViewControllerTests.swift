//Copyright © 2018 Stormbird PTE. LTD.

import FBSnapshotTestCase
@testable import Trust
import UIKit

class EnterSellTicketsPriceQuantityViewControllerTests: FBSnapshotTestCase {
    override func setUp() {
        super.setUp()
        isDeviceAgnostic = true
        recordMode = false
    }

    func testSellTicketsPriceQuantityViewControllerDisplay() {
        let ticket = Token(id: "1", index: 1, name: "", values: ["locality": "", "venue": "", "match": 9, "time": GeneralisedTime(string: "20010203160500+0300")!, "numero": 1, "category": "MATCH CLUB", "countryA": "Team A", "countryB": "Team B"])
        let tokenHolder = TokenHolder(tickets: [ticket], status: .available, contractAddress: "0x1")
        let token = TokenObject(contract: "0x0000000000000000000000000000000000000001", name: "", symbol: "", decimals: 0, value: "", isCustom: true, isDisabled: false, type: .erc875)
        let controller = EnterSellTokensCardPriceQuantityViewController(
                config: Config(),
                storage: FakeTokensDataStore(),
                paymentFlow: .send(type: .ERC875Token(token)),
                ethPrice: .init(nil),
                viewModel: .init(token: token, ticketHolder: tokenHolder)
        )
        controller.configure()
        controller.pricePerTicketField.ethCost = "0.0000001"

        FBSnapshotVerifyView(controller.view)
    }
}
