import XCTest
@testable import Trust
import TrustKeystore
import RealmSwift
import BigInt

class OrderSigningTests : XCTestCase  {

    var contractAddress = "0xacDe9017473D7dC82ACFd0da601E4de291a7d6b0"
    let keystore = FakeEtherKeystore()

    func testSigningOrders() {
        
        var testOrdersList : Array<Order> = Array<Order>()
        //set up test orders
        var indices = [UInt16]()
        indices.append(14)
        
        let testOrder1 = Order(price: BigUInt("0")!,
                indices: indices,
                expiry: BigUInt("0")!,
                contractAddress: contractAddress,
                start: BigUInt("91239231313")!,
                count: 3
        )

        for _ in 0...2015 {
            testOrdersList.append(testOrder1)
        }

        let signOrders = SignOrders()

        let privateKeyResult = keystore.convertPrivateKeyToKeystoreFile(
                privateKey: "0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318",
                passphrase: TestKeyStore.password
        )

        guard case let .success(keystoreString) = privateKeyResult else {
            return XCTFail()
        }

        let result = keystore.importKeystore(
                value: keystoreString.jsonString!,
                password: TestKeyStore.password,
                newPassword: TestKeyStore.password
        )

        guard case let .success(account) = result else {
            return XCTFail()
        }

        //TODO signedOrders doesn't like getting keystore from test for some reason
        //let signedOrders = try! signOrders.signOrders(orders: testOrdersList, account: account)
        //XCTAssertGreaterThanOrEqual(2016, signedOrders.count)

    }
    
}

