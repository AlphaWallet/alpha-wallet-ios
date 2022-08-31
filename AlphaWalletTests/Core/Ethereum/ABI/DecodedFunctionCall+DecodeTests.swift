// Copyright © 2021 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class DecodedFunctionCallTest: XCTestCase {
    func testDecode() {
        let data = Data(hex: "0xa9059cbb0000000000000000000000003e0763abd685b61e6f001ed33601053401415c520000000000000000000000000000000000000000000000000000000153f4cf00")
        let decoded = DecodedFunctionCall.decode(data: data, abi: AlphaWallet.Ethereum.ABI.erc20)
        XCTAssertEqual(decoded?.name, "transfer")
    }

    func testDecode2() {
        let data = Data(hex: "0x095ea7b30000000000000000000000000c6d898ac945e493d25751ea43be2c8beb881d8c000000000000000000000000000000000000000000000000048ae94435bf1640")
        let function = DecodedFunctionCall(data: data)
        XCTAssertEqual(function?.name, "approve")
    }

    func testDecodeDoesNotCrash() {
        ////https://ropsten.etherscan.io/tx/0xf406723cc8e0165ded6e8e268e6576ab1a4f12736f6b90eff1adbca87f79a608
        let data = Data(hex: "000000000000000000000000007bee82bdd9e866b2bd114780a47f2261c684e3000000000000000000000000fe6d4bc2de2d0b0e6fe47f08a28ed52f9d052a020000000000000000000000000000000000000000000000000000000000000001")
        let decoded = DecodedFunctionCall.decode(data: data, abi: AlphaWallet.Ethereum.ABI.erc20)
        XCTAssertNil(decoded)
    }
}
