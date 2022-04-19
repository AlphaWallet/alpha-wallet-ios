import XCTest
@testable import WalletConnect

final class StringExtensionTests: XCTestCase {
    
    func testGenericPasswordConvertible() {
        let string = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let restoredString = try? String(rawRepresentation: string.rawRepresentation)
        XCTAssertEqual(string, restoredString)
    }
    
    func testConformanceToCAIP2() {
        // Minimum and maximum length cases
        XCTAssertTrue(String.conformsToCAIP2("std:0"), "Dummy min length (3+1+1 = 5 chars/bytes)")
        XCTAssertTrue(String.conformsToCAIP2("chainstd:8C3444cf8970a9e41a706fab93e7a6c4"), "Dummy max length (8+1+32 = 41 chars/bytes)")
        
        // Invalid namespace formatting
        XCTAssertFalse(String.conformsToCAIP2("chainstdd:0"), "Namespace overflow")
        XCTAssertFalse(String.conformsToCAIP2("st:00"), "Namespace underflow")
        XCTAssertFalse(String.conformsToCAIP2("chain$td:0"), "Namespace uses special character")
        XCTAssertFalse(String.conformsToCAIP2("Chainstd:0"), "Namespace uses uppercase letter")
        XCTAssertFalse(String.conformsToCAIP2(":8c3444cf8970a9e41a706fab93e7a6c4"), "Empty namespace")
        
        // Invalid reference formatting
        XCTAssertFalse(String.conformsToCAIP2("chainstd:8c3444cf8970a9e41a706fab93e7a6c44"), "Reference overflow")
        XCTAssertFalse(String.conformsToCAIP2("chainstd:0!"), "Reference uses special character")
        XCTAssertFalse(String.conformsToCAIP2("chainstd:"), "Empty reference")
        
        // Malformed identifier
        XCTAssertFalse(String.conformsToCAIP2("chainstd8c3444cf8970a9e41a706fab93e7a6c4"), "No colon")
        XCTAssertFalse(String.conformsToCAIP2("chainstd:8c3444cf8970a9e41a706fab93e7a6c4:"), "Multiple colon in suffix")
        XCTAssertFalse(String.conformsToCAIP2("chainstd:8c3444cf8970a9e:41a706fab93e7a6c"), "Multiple colons")
        XCTAssertFalse(String.conformsToCAIP2(""), "Empty string")
    }
    
    func testRealExamplesConformanceToCAIP2() {
        XCTAssertTrue(String.conformsToCAIP2("eip155:1"), "Ethereum mainnet")
        XCTAssertTrue(String.conformsToCAIP2("bip122:000000000019d6689c085ae165831e93"), "Bitcoin mainnet")
        XCTAssertTrue(String.conformsToCAIP2("bip122:12a765e31ffd4059bada1e25190f6e98"), "Litecoin")
        XCTAssertTrue(String.conformsToCAIP2("bip122:fdbe99b90c90bae7505796461471d89a"), "Feathercoin (Litecoin fork)")
        XCTAssertTrue(String.conformsToCAIP2("cosmos:cosmoshub-2"), "Cosmos Hub (Tendermint + Cosmos SDK)")
        XCTAssertTrue(String.conformsToCAIP2("cosmos:Binance-Chain-Tigris"), "Binance chain (Tendermint + Cosmos SDK)")
        XCTAssertTrue(String.conformsToCAIP2("cosmos:iov-mainnet"), "IOV Mainnet (Tendermint + weave)")
        XCTAssertTrue(String.conformsToCAIP2("lip9:9ee11e9df416b18b"), "Lisk Mainnet (LIP-0009)")
    }
    
    func testConformanceToCAIP10() {
        // Minimum and maximum length cases
        XCTAssertTrue(String.conformsToCAIP10("std:0:0"), "Dummy min length (3+1+1+1+1 = 7 chars/bytes)")
        XCTAssertTrue(String.conformsToCAIP10("chainstd:8c3444cf8970a9e41a706fab93e7a6c4:6d9b0b4b9994e8a6afbd3dc3ed983cd51c755afb27cd1dc7825ef59c134a39f7"), "Dummy max length (64+1+8+1+32 = 106 chars/bytes)")
        
        // Invalid address formatting
        XCTAssertFalse(String.conformsToCAIP10("chainstd:0:6d9b0b4b9994e8a6afbd3dc3ed983cd51c755afb27cd1dc7825ef59c134a39f77"), "Address overflow")
        XCTAssertFalse(String.conformsToCAIP10("chainstd:0:$"), "Address uses special character")
        XCTAssertFalse(String.conformsToCAIP10("chainstd:0:"), "Empty address")
        
        // Malformed identifier
        XCTAssertFalse(String.conformsToCAIP10("st:0:0"), "Bad namespace")
        XCTAssertFalse(String.conformsToCAIP10("std:#:0"), "Bad reference")
        XCTAssertFalse(String.conformsToCAIP10("std::0"), "No reference")
        XCTAssertFalse(String.conformsToCAIP10("chainstd8c3444cf8970a9e41a706fab93e7a6c46d9b0b4b9994e8a6afbd3dc3ed983cd51c755afb27cd1dc7825ef59c134a39f7"), "No colon")
        XCTAssertFalse(String.conformsToCAIP10("chainstd:0:0:"), "Multiple colon in suffix")
        XCTAssertFalse(String.conformsToCAIP10("chainstd:0:0:0"), "Multiple colons")
        XCTAssertFalse(String.conformsToCAIP10("chainstd:0::0"), "Repeated colons")
        XCTAssertFalse(String.conformsToCAIP10(""), "Empty string")
    }
    
    func testRealExamplesConformanceToCAIP10() {
        XCTAssertTrue(String.conformsToCAIP10("eip155:1:0xab16a96d359ec26a11e2c2b3d8f8b8942d5bfcdb"), "Ethereum mainnet")
        XCTAssertTrue(String.conformsToCAIP10("bip122:000000000019d6689c085ae165831e93:128Lkh3S7CkDTBZ8W7BbpsN3YYizJMp8p6"), "Bitcoin mainnet")
        XCTAssertTrue(String.conformsToCAIP10("cosmos:cosmoshub-3:cosmos1t2uflqwqe0fsj0shcfkrvpukewcw40yjj6hdc0"), "Cosmos Hub")
        XCTAssertTrue(String.conformsToCAIP10("polkadot:b0a8d493285c2df73290dfb7e61f870f:5hmuyxw9xdgbpptgypokw4thfyoe3ryenebr381z9iaegmfy"), "Kusama network")
    }
}
