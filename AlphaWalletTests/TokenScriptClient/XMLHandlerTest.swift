//
//  XMLHandlerTest.swift
//  AlphaWalletTests
//
//  Created by James Sangalli on 11/4/18.
//

import Foundation
import XCTest
@testable import AlphaWallet
import BigInt

class XMLHandlerTest: XCTestCase {
    let tokenHex = "0x00000000000000000000000000000000fefe5ae99a3000000000000000010001".substring(from: 2)

    override func tearDown() {
        XMLHandler.invalidateAllContracts()
    }

    func testParser() {
        let assetDefinitionStore = AssetDefinitionStore()
        let token = XMLHandler(contract: Constants.nullAddress, assetDefinitionStore: assetDefinitionStore).getToken(
                name: "",
                symbol: "",
                fromTokenId: BigUInt(tokenHex, radix: 16)!,
                index: UInt16(1),
                inWallet: .make(),
                server: .main
        )
        XCTAssertNotNil(token)
    }

    //TODO fix test
//    func testHasAssetDefinition() {
//        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore())
//        let address1 = AlphaWallet.Address.ethereumAddress(eip55String: "0x0000000000000000000000000000000000000001")
//        let address2 = AlphaWallet.Address.ethereumAddress(eip55String: "0x0000000000000000000000000000000000000002")
//        store[address1] = ""
//        XCTAssertTrue(XMLHandler(contract: address1.eip55String, assetDefinitionStore: store).hasAssetDefinition)
//        XCTAssertFalse(XMLHandler(contract: address2.eip55String, assetDefinitionStore: store).hasAssetDefinition)
//    }

    func testExtractingAttributesWithNamespaceInXML() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <ts:token xmlns:ts="http://tokenscript.org/2019/05/tokenscript"
                    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                    xsi:schemaLocation="http://tokenscript.org/2019/05/tokenscript ../../tsml.xsd"
                    xmlns:xml="http://www.w3.org/XML/1998/namespace">
          <ts:contract id="holding_contract" type="holding">
            <ts:address network="1">0x830E1650a87a754e37ca7ED76b700395A7C61614</ts:address>
            <ts:name xml:lang="en">Tickets</ts:name>
            <ts:name xml:lang="zh">门票</ts:name>
            <ts:name xml:lang="es">Entradas</ts:name>
            <ts:interface>erc875</ts:interface>
          </ts:contract>
          <ts:attribute-types>
            <ts:attribute-type id="locality" syntax="1.3.6.1.4.1.1466.115.121.1.15">
              <ts:name xml:lang="en">City</ts:name>
              <ts:name xml:lang="zh">城市</ts:name>
              <ts:name xml:lang="es">Ciudad</ts:name>
              <ts:name xml:lang="ru">город</ts:name>
              <ts:origins>
                <ts:token-id bitmask="00000000000000000000000000000000FF000000000000000000000000000000" as="uint">
                  <ts:mapping>
                    <ts:option key="1">
                      <ts:value xml:lang="ru">Москва́</ts:value>
                      <ts:value xml:lang="en">Moscow</ts:value>
                      <ts:value xml:lang="zh">莫斯科</ts:value>
                      <ts:value xml:lang="es">Moscú</ts:value>
                    </ts:option>
                    <ts:option key="2">
                      <ts:value xml:lang="ru">Санкт-Петербу́рг</ts:value>
                      <ts:value xml:lang="en">Saint Petersburg</ts:value>
                  </ts:mapping>
                </ts:token-id>
              </ts:origins>
            </ts:attribute-type>
          </ts:attribute-types>
        </ts:token>
        """
        let contractAddress = AlphaWallet.Address.make()
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore())
        store[contractAddress] = xml
        let xmlHandler = XMLHandler(contract: contractAddress, assetDefinitionStore: store)
        let tokenId = BigUInt("0000000000000000000000000000000002000000000000000000000000000000", radix: 16)!
        let server: RPCServer = .main
        let token = xmlHandler.getToken(name: "Some name", symbol: "Some symbol", fromTokenId: tokenId, index: 1, inWallet: .make(), server: server)
        let values = token.values
        XCTAssertEqual(values["locality"]?.stringValue, "Saint Petersburg")
    }

    //TODO fix test
//    func testNoAssetDefinition() {
//        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore())
//        let xmlHandler = XMLHandler(contract: "0x1", assetDefinitionStore: store)
//        let tokenId = BigUInt("0000000000000000000000000000000002000000000000000000000000000000", radix: 16)!
//        let server: RPCServer = .main
//        let token = xmlHandler.getToken(name: "Some name", symbol: "Some symbol", fromTokenId: tokenId, index: 1, inWallet: .make(), server: server)
//        let values = token.values
//        XCTAssertTrue(values.isEmpty)
//    }

    func testXPathNamePrefixing() {
        XCTAssertEqual("".addToXPath(namespacePrefix: "tb1:"), "")
        XCTAssertEqual("/part1/part2/part3".addToXPath(namespacePrefix: "tb1:"), "/tb1:part1/tb1:part2/tb1:part3")
        XCTAssertEqual("part1/part2/part3".addToXPath(namespacePrefix: "tb1:"), "tb1:part1/tb1:part2/tb1:part3")
    }
}
