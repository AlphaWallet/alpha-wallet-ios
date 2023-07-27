// Copyright © 2018 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
import Foundation
import AlphaWalletFoundation

class TokenObjectTest: XCTestCase {
    func testCheckNonZeroBalance() {
        XCTAssertFalse(isNonZeroBalance(Constants.nullTokenId, tokenType: .erc875))
    }

    func testTokenInfo() async {
        let dataStore = FakeTokensDataStore()
        let _token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000004"), type: .erc20)
        await dataStore.addOrUpdate(with: [.init(_token)])

        let token1 = await dataStore.token(for: _token.contractAddress, server: _token.server)

        XCTAssertNotNil(token1?.info)
        XCTAssertEqual(token1?.info, _token.info)

        let url = URL(string: "http://google.com")
        await dataStore.addOrUpdate(with: [.update(token: _token, field: .imageUrl(url))])

        let token2 = await dataStore.token(for: _token.contractAddress, server: _token.server)
        XCTAssertEqual(token2?.info.imageUrl, url?.absoluteString)

        await dataStore.addOrUpdate(with: [.update(token: _token, field: .imageUrl(nil))])

        let token3 = await dataStore.token(for: _token.contractAddress, server: _token.server)
        XCTAssertNil(token3?.info.imageUrl)
    }

    func testTokenBalanceDeletion() async {
        let dataStore = FakeTokensDataStore()
        let _token = Token(contract: AlphaWallet.Address.make(address: "0x1000000000000000000000000000000000000004"), type: .erc721)
        await dataStore.addOrUpdate(with: [.init(_token)])

        let _token1 = await dataStore.token(for: _token.contractAddress, server: _token.server)
        XCTAssertEqual(_token1?.balance, [])

        await dataStore.updateToken(primaryKey: _token.primaryKey, action: .nonFungibleBalance(.balance(["test balance"])))

        let balances1 = await dataStore.tokenBalancesTestsOnly()
        XCTAssertEqual(balances1.count, 1)

        await dataStore.updateToken(primaryKey: _token.primaryKey, action: .nonFungibleBalance(.balance([])))

        let balances2 = await dataStore.tokenBalancesTestsOnly()
        XCTAssertEqual(balances2.count, 0)

        let _token2 = await dataStore.token(for: _token.contractAddress, server: _token.server)
        XCTAssertEqual(_token2?.balance, [])
    }
}
