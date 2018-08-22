//Copyright © 2018 Stormbird PTE. LTD.

import FBSnapshotTestCase
@testable import Trust
import UIKit

class TransferTokensQuantitySelectionViewControllerTests: FBSnapshotTestCase {
    override func setUp() {
        super.setUp()
        isDeviceAgnostic = true
        recordMode = false
    }

    func testTransferTokenQuantitySelectionViewControllerCanBeCreated() {
        let token = TokenObject()
        let type = PaymentFlow.send(type: .ERC875Token(token))
        let Token = Token(id: "1", index: 1, name: "", values: ["city": "", "venue": "", "match": 9, "time": GeneralisedTime(string: "20010203160500+0300")!, "numero": 1, "category": "MATCH CLUB", "countryA": "Team A", "countryB": "Team B"])
        let TokenHolder = TokenHolder(Tokens: [Token], status: .available, contractAddress: "0x1")
        let viewModel = TransferTokensQuantitySelectionViewModel(token: token, TokenHolder: TokenHolder)
        let controller = TransferTokensQuantitySelectionViewController(paymentFlow: type, token: token, viewModel: viewModel)
        controller.configure()

        FBSnapshotVerifyView(controller.view)
    }
}
