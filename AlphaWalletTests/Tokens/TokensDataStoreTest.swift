// Copyright © 2018 Stormbird PTE. LTD.

@testable import AlphaWallet
import AlphaWalletFoundation
import Foundation
import XCTest

class TokensDataStoreTest: XCTestCase {
    private let storage = FakeTokensDataStore()
    private let token = Token(
        contract: AlphaWallet.Address.make(),
        server: .main,
        value: "0",
        type: .erc20
    )

    override func setUp() {
        storage.addOrUpdate(with: [.init(token)])
    }

    //We make a call to update token in datastore to store the updated balance after an async call to fetch the balance over the web. Token in the datastore might have been deleted when the web call is completed. Make sure this doesn't crash
    func testUpdateDeletedTokensDoNotCrash() {
        storage.deleteTestsOnly(tokens: [token])
        XCTAssertNil(storage.updateToken(primaryKey: token.primaryKey, action: .value(1)))
    }

    //Ensure this works:
    //1. Copy contract address for a token to delete (actually hide).
    //2. Swipe to hide the token.
    //3. Manually add that token back (add custom token screen)
    //4. Swipe to hide that token.
    //5. BOOM.
    func testHideContractTwiceDoesNotCrash() {
        let contract = AlphaWallet.Address(string: "0x66F08Ca6892017A45Da6FB792a8E946FcBE3d865")!
        storage.add(hiddenContracts: [AddressAndRPCServer(address: contract, server: .goerli)])
        XCTAssertNoThrow(storage.add(hiddenContracts: [AddressAndRPCServer(address: contract, server: .goerli)]))
    }
}
