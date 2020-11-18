//Copyright © 2018 Stormbird PTE. LTD.

import FBSnapshotTestCase
@testable import AlphaWallet
import UIKit

class TransferTokensCardQuantitySelectionViewControllerTests: FBSnapshotTestCase {
    override func setUp() {
        super.setUp()
        recordMode = false
    }

    //TODO restore after confirm send/receive buttons
//    func testTransferTokensCardQuantitySelectionViewControllerCanBeCreated() {
//        let tokenObject = TokenObject(contract: "0x0000000000000000000000000000000000000001", name: "", symbol: "", decimals: 0, value: "", isCustom: true, isDisabled: false, type: .erc875)
//        let type = PaymentFlow.send(type: .ERC875Token(tokenObject))
//        let token = Token(id: "1", index: 1, name: "", status: .available, values: ["city": "", "venue": "", "match": 9, "time": GeneralisedTime(string: "20010203160500+0300")!, "numero": 1, "category": "MATCH CLUB", "countryA": "Team A", "countryB": "Team B"])
//        let tokenHolder = TokenHolder(tokens: [token], contractAddress: "0x1", hasAssetDefinition: true)
//        let viewModel = TransferTokensCardQuantitySelectionViewModel(token: tokenObject, tokenHolder: tokenHolder)
//        let controller = TransferTokensCardQuantitySelectionViewController(paymentFlow: type, token: tokenObject, viewModel: viewModel)
//        controller.configure()

//        FBSnapshotVerifyView(controller.view)
//    }
}
