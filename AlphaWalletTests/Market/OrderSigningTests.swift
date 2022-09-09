import XCTest
@testable import AlphaWallet
import BigInt
import AlphaWalletFoundation

class OrderSigningTests: XCTestCase {

    func testSigningOrders() {
        let keystore = FakeEtherKeystore()
        let contractAddress = AlphaWallet.Address(string: "0xacDe9017473D7dC82ACFd0da601E4de291a7d6b0")!
        guard let account = try? keystore.createAccount().get().address else {
            XCTFail("Failure to import wallet")
            return
        }
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
        let prompt = R.string.localizable.keystoreAccessKeySign()
        let signOrders = OrderHandler(keystore: keystore, prompt: prompt)
        guard let signedOrders = try? signOrders.signOrders(orders: testOrdersList, account: account, tokenType: TokenType.erc875) else {
            XCTFail("Failure to sign an order")
            return
        }
        XCTAssertGreaterThanOrEqual(2016, signedOrders.count)
        keystore.delete(wallet: Wallet(address: account, origin: .hd))
    }
}

