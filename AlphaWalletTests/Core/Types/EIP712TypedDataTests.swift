import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class EIP712TypedDataTests: XCTestCase {
    //Sample is verbatim from OpenSea
// swiftlint:disable function_body_length
    func testPickUpStructNameFromArrayOfStructs() {
        let string = """
                     {
                        "domain" : {
                           "chainId" : "1",
                           "name" : "Seaport",
                           "verifyingContract" : "0x00000000006c3852cbEf3e08E8dF289169EdE581",
                           "version" : "1.1"
                        },
                        "message" : {
                           "conduitKey" : "0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000",
                           "consideration" : [
                              {
                                 "endAmount" : "1",
                                 "identifierOrCriteria" : "82551987290052721597115857679861333532051873376225208613649240710759910735405",
                                 "itemType" : "2",
                                 "recipient" : "0xbbce83173d5c1D122AE64856b4Af0D5AE07Fa362",
                                 "startAmount" : "1",
                                 "token" : "0xD1E5b0FF1287aA9f9A268759062E4Ab08b9Dacbe"
                              }
                           ],
                           "counter" : "0",
                           "endTime" : "1662967989",
                           "offer" : [
                              {
                                 "endAmount" : "1",
                                 "identifierOrCriteria" : "0",
                                 "itemType" : "1",
                                 "startAmount" : "1",
                                 "token" : "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
                              }
                           ],
                           "offerer" : "0xbbce83173d5c1D122AE64856b4Af0D5AE07Fa362",
                           "orderType" : "2",
                           "salt" : "4581167412362157",
                           "startTime" : "1660282068",
                           "totalOriginalConsiderationItems" : "1",
                           "zone" : "0x004C00500000aD104D7DBd00e3ae0A5C00560C00",
                           "zoneHash" : "0x0000000000000000000000000000000000000000000000000000000000000000"
                        },
                        "primaryType" : "OrderComponents",
                        "types" : {
                           "ConsiderationItem" : [
                              {
                                 "name" : "itemType",
                                 "type" : "uint8"
                              },
                              {
                                 "name" : "token",
                                 "type" : "address"
                              },
                              {
                                 "name" : "identifierOrCriteria",
                                 "type" : "uint256"
                              },
                              {
                                 "name" : "startAmount",
                                 "type" : "uint256"
                              },
                              {
                                 "name" : "endAmount",
                                 "type" : "uint256"
                              },
                              {
                                 "name" : "recipient",
                                 "type" : "address"
                              }
                           ],
                           "EIP712Domain" : [
                              {
                                 "name" : "name",
                                 "type" : "string"
                              },
                              {
                                 "name" : "version",
                                 "type" : "string"
                              },
                              {
                                 "name" : "chainId",
                                 "type" : "uint256"
                              },
                              {
                                 "name" : "verifyingContract",
                                 "type" : "address"
                              }
                           ],
                           "OfferItem" : [
                              {
                                 "name" : "itemType",
                                 "type" : "uint8"
                              },
                              {
                                 "name" : "token",
                                 "type" : "address"
                              },
                              {
                                 "name" : "identifierOrCriteria",
                                 "type" : "uint256"
                              },
                              {
                                 "name" : "startAmount",
                                 "type" : "uint256"
                              },
                              {
                                 "name" : "endAmount",
                                 "type" : "uint256"
                              }
                           ],
                           "OrderComponents" : [
                              {
                                 "name" : "offerer",
                                 "type" : "address"
                              },
                              {
                                 "name" : "zone",
                                 "type" : "address"
                              },
                              {
                                 "name" : "offer",
                                 "type" : "OfferItem[]"
                              },
                              {
                                 "name" : "consideration",
                                 "type" : "ConsiderationItem[]"
                              },
                              {
                                 "name" : "orderType",
                                 "type" : "uint8"
                              },
                              {
                                 "name" : "startTime",
                                 "type" : "uint256"
                              },
                              {
                                 "name" : "endTime",
                                 "type" : "uint256"
                              },
                              {
                                 "name" : "zoneHash",
                                 "type" : "bytes32"
                              },
                              {
                                 "name" : "salt",
                                 "type" : "uint256"
                              },
                              {
                                 "name" : "conduitKey",
                                 "type" : "bytes32"
                              },
                              {
                                 "name" : "counter",
                                 "type" : "uint256"
                              }
                           ]
                        }
                     }
                     """
        guard let data = string.data(using: .utf8), let object = try? JSONDecoder().decode(EIP712TypedData.self, from: data) else {
            XCTFail("Failed to parse EIP712TypedData JSON")
            return
        }
        let dependencies = object.findDependencies(primaryType: "OrderComponents")
        XCTAssertEqual(dependencies, Set(["OrderComponents", "OfferItem", "ConsiderationItem"]))
    }
// swiftlint:enable function_body_length
}
