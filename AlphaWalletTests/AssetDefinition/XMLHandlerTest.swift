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
        let token = XMLHandler(contract: "0x").getToken(
                name: "",
                fromTokenId: BigUInt(tokenHex, radix: 16)!,
                index: UInt16(1),
                server: .main
        )
        XCTAssertNotNil(token)
    }

    func testHasAssetDefinition() {
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore())
        store["0x1"] = ""
        XCTAssertTrue(XMLHandler(contract: "0x1", assetDefinitionStore: store).hasAssetDefinition)
        XCTAssertFalse(XMLHandler(contract: "0x2", assetDefinitionStore: store).hasAssetDefinition)
    }

    func testExtractingAttributesWithNamespaceInXML() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <tbml:token xmlns:tbml="http://attestation.id/ns/tbml"
                    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                    xsi:schemaLocation="http://attestation.id/ns/tbml ../../tbml.xsd"
                    xmlns:xml="http://www.w3.org/XML/1998/namespace">
          <tbml:contract id="holding_contract" type="holding">
            <tbml:address network="1">0x830E1650a87a754e37ca7ED76b700395A7C61614</tbml:address>
            <tbml:name xml:lang="en">Tickets</tbml:name>
            <tbml:name xml:lang="zh">门票</tbml:name>
            <tbml:name xml:lang="es">Entradas</tbml:name>
            <tbml:interface>erc875</tbml:interface>
          </tbml:contract>
          <tbml:attribute-types>
            <tbml:attribute-type id="locality" oid="2.5.4.7" syntax="1.3.6.1.4.1.1466.115.121.1.15">
              <tbml:name xml:lang="en">City</tbml:name>
              <tbml:name xml:lang="zh">城市</tbml:name>
              <tbml:name xml:lang="es">Ciudad</tbml:name>
              <tbml:name xml:lang="ru">город</tbml:name>
              <tbml:origin bitmask="00000000000000000000000000000000FF000000000000000000000000000000" as="mapping">
                <tbml:mapping>
                  <tbml:option key="1">
                    <tbml:value xml:lang="ru">Москва́</tbml:value>
                    <tbml:value xml:lang="en">Moscow</tbml:value>
                    <tbml:value xml:lang="zh">莫斯科</tbml:value>
                    <tbml:value xml:lang="es">Moscú</tbml:value>
                  </tbml:option>
                  <tbml:option key="2">
                    <tbml:value xml:lang="ru">Санкт-Петербу́рг</tbml:value>
                    <tbml:value xml:lang="en">Saint Petersburg</tbml:value>
                </tbml:mapping>
              </tbml:origin>
            </tbml:attribute-type>
          </tbml:attribute-types>
        </tbml:token>
        """
        let contractAddress = "0x1"
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore())
        store[contractAddress] = xml
        let xmlHandler = XMLHandler(contract: contractAddress, assetDefinitionStore: store)
        let tokenId = BigUInt("0000000000000000000000000000000002000000000000000000000000000000", radix: 16)!
        let server: RPCServer = .main
        let token = xmlHandler.getToken(name: "Some name", fromTokenId: tokenId, index: 1, server: server)
        let values = token.values
        XCTAssertEqual(values["locality"] as? String, "Saint Petersburg")
    }

    func testNoAssetDefinition() {
        let store = AssetDefinitionStore(backingStore: AssetDefinitionInMemoryBackingStore())
        let xmlHandler = XMLHandler(contract: "0x1", assetDefinitionStore: store)
        let tokenId = BigUInt("0000000000000000000000000000000002000000000000000000000000000000", radix: 16)!
        let server: RPCServer = .main
        let token = xmlHandler.getToken(name: "Some name", fromTokenId: tokenId, index: 1, server: server)
        let values = token.values
        XCTAssertTrue(values.isEmpty)
    }

    func testXPathNamePrefixing() {
        XCTAssertEqual("".addToXPath(namespacePrefix: "tb1:"), "")
        XCTAssertEqual("/part1/part2/part3".addToXPath(namespacePrefix: "tb1:"), "/tb1:part1/tb1:part2/tb1:part3")
        XCTAssertEqual("part1/part2/part3".addToXPath(namespacePrefix: "tb1:"), "tb1:part1/tb1:part2/tb1:part3")
    }
}
