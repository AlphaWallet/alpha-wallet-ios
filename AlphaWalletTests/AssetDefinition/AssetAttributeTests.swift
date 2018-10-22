// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import XCTest
@testable import AlphaWallet
import SwiftyXMLParser

class AssetAttributeTests: XCTestCase {
    private func extract(withBitmask bitmask: String, tokenValueHex: String) -> String {
        let xmlString = "<token>" +
                "<attribute-types>" +
                "  <attribute-type id=\"attribute_name\" syntax=\"1.3.6.1.4.1.1466.115.121.1.26\">" +
                "    <origin as=\"utf8\" bitmask=\"" + bitmask + "\"/>" +
                "  </attribute-type>" +
                "</attribute-types>" +
                "</token>"
        let xml = try! XML.parse(xmlString)
        let accessor = xml["token"]["attribute-types"]["attribute-type"][0]
        guard case let .singleElement(element) = accessor else {
            XCTAssertTrue(false)
            return "N/A"
        }
        let attribute = AssetAttribute(attribute: element, lang: "en")

        let countryA: String = attribute.extract(from: tokenValueHex) ?? "N/A"
        return countryA
    }

    func testBitMask() {
        XCTAssertEqual(extract(withBitmask: "00000000000000000000000000000000000000000000FFFFFF00000000000000", tokenValueHex: "000000000000414C4600000000000000"), "ALF")
        XCTAssertEqual(extract(withBitmask: "00000000000000000000000000000000000000000000000000FFFFFF00000000", tokenValueHex: "000000000000000000494E5600000000"), "INV")
        XCTAssertEqual(extract(withBitmask: "00000000000000000000000000000000000000000000000000000000000000FF", tokenValueHex: "00000000000000000000000000000042"), "B")
        XCTAssertEqual(extract(withBitmask: "00000000000000000000000000000000000000000000000000000000000000FD", tokenValueHex: "00000000000000000000000000000042"), "@")
    }
}
