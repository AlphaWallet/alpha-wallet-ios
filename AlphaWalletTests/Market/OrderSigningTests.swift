import XCTest
@testable import AlphaWallet
import RealmSwift
import BigInt

class OrderSigningTests: XCTestCase {

    func testSigningOrders() {
        let keystore = try! EtherKeystore(analyticsCoordinator: FakeAnalyticsService())
        let contractAddress = AlphaWallet.Address(string: "0xacDe9017473D7dC82ACFd0da601E4de291a7d6b0")!
        let account = try! keystore.createAccount().dematerialize()
        var testOrdersList = [Order]()
        //set up test orders
        var indices = [UInt16]()
        indices.append(14)

        let testOrder1 = Order(price: BigUInt("0")!,
                               indices: indices,
                               expiry: BigUInt("0")!,
                               contractAddress: contractAddress,
                               count: 3,
                               nonce: BigUInt(0),
                               tokenIds: [BigUInt](),
                               spawnable: false,
                               nativeCurrencyDrop: false
        )
        for _ in 0...2015 {
            testOrdersList.append(testOrder1)
        }
        let signOrders = OrderHandler(keystore: keystore)
        let signedOrders = try! signOrders.signOrders(orders: testOrdersList, account: account, tokenType: TokenType.erc875)
        XCTAssertGreaterThanOrEqual(2016, signedOrders.count)
        keystore.delete(wallet: Wallet(type: WalletType.real(account)))
    }
}

