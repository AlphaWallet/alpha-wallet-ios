//
//  RpcNetworkTestCase.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 20/12/21.
//

@testable import AlphaWallet
import AlphaWalletFoundation
import XCTest

class RpcNetworkTestCase: XCTestCase {
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
