//Copyright © 2018 Stormbird PTE. LTD.

import FBSnapshotTestCase
@testable import AlphaWallet
import UIKit

class ImportTokenViewControllerTests: FBSnapshotTestCase {
    override func setUp() {
        super.setUp()
        recordMode = false
    }

    //TODO restore after confirm send/receive buttons
//    func testImportTokenViewControllerDisplay() {
//        let config = Config()
//        let controller = ImportMagicTokenViewController(config: config)
//        var viewModel: ImportMagicTokenViewControllerViewModel = .init(state: .validating, server: config.server)
//        let token = Token(id: "1", index: 1, name: "", status: .available, values: ["locality": "", "venue": "", "match": 9, "time": GeneralisedTime(string: "20010203160500+0300")!, "numero": 1, "category": "MATCH CLUB", "countryA": "Team A", "countryB": "Team B"])
//        let tokenHolder = TokenHolder(tokens: [token], contractAddress: "0x1", hasAssetDefinition: true)
//        let cost: ImportMagicTokenViewControllerViewModel.Cost = .paid(eth: Decimal(1), dollar: Decimal(400))

//        viewModel.tokenHolder = tokenHolder
//        viewModel.state = .promptImport
//        viewModel.cost = cost
//        controller.configure(viewModel: viewModel)

//        FBSnapshotVerifyView(controller.view)
//    }
}
