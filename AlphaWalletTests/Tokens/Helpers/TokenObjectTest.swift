// Copyright © 2018 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
import Foundation
import AlphaWalletFoundation

class TokenObjectTest: XCTestCase {
    func testCheckNonZeroBalance() {
        XCTAssertFalse(isNonZeroBalance(Constants.nullTokenId, tokenType: .erc875))
    }

    func testTokenInfo() {
        let dataStore = FakeTokensDataStore()
        let _token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000004"), type: .erc20)
        dataStore.addOrUpdate(tokensOrContracts: [.token(_token)])

        let token1 = dataStore.token(forContract: _token.contractAddress, server: _token.server)

        XCTAssertNotNil(token1?.info)
        XCTAssertEqual(token1?.info, _token.info)

        let url = URL(string: "http://google.com")
        dataStore.addOrUpdate([.update(token: _token, action: .imageUrl(url))])

        let token2 = dataStore.token(forContract: _token.contractAddress, server: _token.server)
        XCTAssertEqual(token2?.info.imageUrl, url?.absoluteString)

        dataStore.addOrUpdate([.update(token: _token, action: .imageUrl(nil))])

        let token3 = dataStore.token(forContract: _token.contractAddress, server: _token.server)
        XCTAssertNil(token3?.info.imageUrl)
    }

    func testTokenBalanceDeletion() {
        let dataStore = FakeTokensDataStore()
        let _token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000004"), type: .erc721)
        dataStore.addOrUpdate(tokensOrContracts: [.token(_token)])

        let _token1 = dataStore.token(forContract: _token.contractAddress, server: _token.server)
        XCTAssertEqual(_token1?.balance, [])

        dataStore.updateToken(primaryKey: _token.primaryKey, action: .nonFungibleBalance(.balance(["test balance"])))

        let balances1 = dataStore.tokenBalancesTestsOnly()
        XCTAssertEqual(balances1.count, 1)

        dataStore.updateToken(primaryKey: _token.primaryKey, action: .nonFungibleBalance(.balance([])))

        let balances2 = dataStore.tokenBalancesTestsOnly()
        XCTAssertEqual(balances2.count, 0)

        let _token2 = dataStore.token(forContract: _token.contractAddress, server: _token.server)
        XCTAssertEqual(_token2?.balance, [])
    }
}
