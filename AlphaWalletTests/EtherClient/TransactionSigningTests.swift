// Copyright SIX DAY LLC. All rights reserved.

import BigInt
@testable import AlphaWallet
import XCTest

class TransactionSigningTests: XCTestCase {
    func testEIP155SignHash() {
        let address = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x3535353535353535353535353535353535353535")!
        let transaction = UnsignedTransaction(
            value: BigInt("1000000000000000000"),
            account: address,
            to: address,
            nonce: 9,
            data: Data(),
            gasPrice: BigInt("20000000000"),
            gasLimit: BigInt("21000"),
            server: .main,
            transactionType: .nativeCryptocurrency(MultipleChainsTokensDataStore.functional.etherToken(forServer: .main), destination: nil, amount: nil)
        )
        let signer = EIP155Signer(server: .main)
        do {
            let hash = try signer.hash(transaction: transaction)

            XCTAssertEqual(hash.hex(), "daf5a779ae972f972197303d7b574746c7ef83eadac0f2791ad23db92e4c8e53")
        } catch {
            XCTAssertThrowsError(error)
        }
    }

    func testHomesteadSignHash() {
        let address = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x3535353535353535353535353535353535353535")!
        let transaction = UnsignedTransaction(
            value: BigInt("1000000000000000000"),
            account: address,
            to: address,
            nonce: 9,
            data: Data(),
            gasPrice: BigInt("20000000000"),
            gasLimit: BigInt("21000"),
            server: .main,
            transactionType: .nativeCryptocurrency(MultipleChainsTokensDataStore.functional.etherToken(forServer: .main), destination: nil, amount: nil)
        )
        let signer = HomesteadSigner()
        let hash = signer.hash(transaction: transaction)

        XCTAssertEqual(hash.hex(), "f9e36c28c8cb35adba138005c02ab7aa7fbcd891f3139cb2eeed052a51cd2713")
    }

    func testSignTransaction() {
        let account: AlphaWallet.Address = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x3535353535353535353535353535353535353535")!
        let transaction = UnsignedTransaction(
            value: BigInt("1000000000000000000"),
            account: account,
            to: AlphaWallet.Address(uncheckedAgainstNullAddress: "0x3535353535353535353535353535353535353535")!,
            nonce: 9,
            data: Data(),
            gasPrice: BigInt(20000000000),
            gasLimit: BigInt(21000),
            server: .main,
            transactionType: .nativeCryptocurrency(MultipleChainsTokensDataStore.functional.etherToken(forServer: .main), destination: nil, amount: nil)
        )

        let signer = EIP155Signer(server: .main)

        do {
            let hash = try signer.hash(transaction: transaction)
            let expectedHash = Data(hexString: "daf5a779ae972f972197303d7b574746c7ef83eadac0f2791ad23db92e4c8e53")!
            XCTAssertEqual(hash, expectedHash)
        } catch {
            XCTAssertThrowsError(error)
        }
        let signature = Data(hexString: "28ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa63627667cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d8300")!
        let (r, s, v) = signer.values(transaction: transaction, signature: signature)
        XCTAssertEqual(v, BigInt(37))
        XCTAssertEqual(r, BigInt("18515461264373351373200002665853028612451056578545711640558177340181847433846"))
        XCTAssertEqual(s, BigInt("46948507304638947509940763649030358759909902576025900602547168820602576006531"))
    }
}
