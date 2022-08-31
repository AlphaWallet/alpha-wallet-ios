//
//  RpcNetworkTestCase.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 20/12/21.
//

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class RpcNetworkTestCase: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAvailableNetworks() throws {
        guard let availableNetworks = RpcNetwork.functional.availableServersFromCompressedJSONFile(filePathUrl: R.file.chainsZip()) else {
            XCTFail()
            return
        }
        XCTAssert(!availableNetworks.isEmpty)
        let viewModel = SaveCustomRpcManualEntryViewModel(operation: .add)
        availableNetworks.forEach { network in
            switch viewModel.validate(customRpc: network) {
            case .failure:
                XCTFail()
            default:
                return
            }
        }
    }
}
