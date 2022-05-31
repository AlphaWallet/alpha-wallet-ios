// Copyright © 2018 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
import Foundation

class TokenObjectTest: XCTestCase {
    func testCheckNonZeroBalance() {
        XCTAssertFalse(isNonZeroBalance(Constants.nullTokenId, tokenType: .erc875))
    }

    func testTokenInfo() {
        let dataStore = FakeTokensDataStore()
        let token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000004"), type: .erc20)
        dataStore.addTokenObjects(values: [.token(token)])

        let tokenObject = dataStore.tokenObject(forContract: token.contractAddress, server: token.server)

        XCTAssertNotNil(tokenObject?._info)
        XCTAssertEqual(tokenObject?._info, tokenObject?.info)

        let token1 = dataStore.token(forContract: token.contractAddress, server: token.server)

        XCTAssertNotNil(token1?.info)
        XCTAssertEqual(token1?.info, token.info)

        let url = URL(string: "http://google.com")
        dataStore.batchUpdateToken([.update(token: token, action: .imageUrl(url))])

        let token2 = dataStore.token(forContract: token.contractAddress, server: token.server)
        XCTAssertEqual(token2?.info.imageUrl, url?.absoluteString)

        dataStore.batchUpdateToken([.update(token: token, action: .imageUrl(nil))])

        let token3 = dataStore.token(forContract: token.contractAddress, server: token.server)
        XCTAssertNil(token3?.info.imageUrl)
    }
}
