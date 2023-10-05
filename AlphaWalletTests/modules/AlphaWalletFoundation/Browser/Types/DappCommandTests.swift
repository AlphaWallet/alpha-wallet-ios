// Copyright © 2022 Stormbird PTE. LTD.

import XCTest
import AlphaWalletBrowser
@testable import AlphaWalletFoundation

class DappCommandTests: XCTestCase {
    func testParsingDappCommandWithNullValues() {
        let jsonString = """
                         {
                            "id" : 8888,
                            "name" : "signTransaction",
                            "object" : {
                               "chainId" : 1,
                               "chainType" : "ETH",
                               "data" : "0x54bacd13000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000def1c0ded9bec7f1a1670819833240f027b25eff00000000000000000000000000000000000000000000000031ce0348a2028e4c0000000000000000000000000000000000000000000000f4c062a04cdfc38c3b0000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000634fa29000000000000000000000000000000000000000000000000000000000000001283598d8ab00000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000f4c062a04cdfc38c3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000042c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f4a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000646b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000000000000000000000869584cd000000000000000000000000221d5c4993297fd95fa17743b9297e2e49fce9d200000000000000000000000000000000000000000000003419724979634f9de2000000000000000000000000000000000000000000000000",
                               "from" : "0xbbce83173d5c1d122ae64856b4af0d5ae07fa362",
                               "gas" : "0x4cbb2",
                               "gasLimit" : "0x4cbb2",
                               "maxFeePerGas" : null,
                               "maxPriorityFeePerGas" : null,
                               "nonce" : "0xf7",
                               "to" : "0xa356867fdcea8e71aeaf87805808803806231fdc",
                               "value" : "0x31ce0348a2028e4c"
                            }
                          }
                         """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        XCTAssertNil(try? decoder.decode(DappCommand.self, from: data))

        if let commandWithOptionalObjectValues = try? decoder.decode(DappCommandWithOptionalObjectValues.self, from: data) {
            XCTAssertEqual(commandWithOptionalObjectValues.object.count, 11)
            XCTAssertEqual(commandWithOptionalObjectValues.toCommand.object.count, 9)
        } else {
            XCTFail("Should be able to parse dapp command with unexpected values")
        }
    }
}