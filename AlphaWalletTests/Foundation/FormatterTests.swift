//
//  FormattersTests.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 19/1/22.
//

@testable import AlphaWallet
import XCTest
import AlphaWalletFoundation

class FormattersTestCase: XCTestCase {

    func testCurrency() {
        XCTAssertEqual(Formatter.currency.string(from: 0.0)!, "$0.00")
        XCTAssertEqual(Formatter.currency.string(from: 10.100)!, "$10.10")
        XCTAssertEqual(Formatter.currency.string(from: 100.105)!, "$100.10")
        XCTAssertEqual(Formatter.currency.string(from: 1000.109)!, "$1,000.10")
        XCTAssertEqual(Formatter.currency.string(from: 9999999999999.999)!, "$9,999,999,999,999.99")
        XCTAssertEqual(Formatter.currency.string(from: -0.0)!, "-$0.00")
        XCTAssertEqual(Formatter.currency.string(from: -10.100)!, "-$10.10")
        XCTAssertEqual(Formatter.currency.string(from: -100.105)!, "-$100.10")
        XCTAssertEqual(Formatter.currency.string(from: -1000.109)!, "-$1,000.10")
        XCTAssertEqual(Formatter.currency.string(from: -9999999999999.999)!, "-$9,999,999,999,999.99")
        // XCTAssertEqual(Formatters.currency.string(from: 123456789123456789.056), "$123,456,789,123,456,789.05")
    }

    func testUsd() {
        XCTAssertEqual(Formatter.usd.string(from: 0.0)!, "0.00 USD")
        XCTAssertEqual(Formatter.usd.string(from: 10.100)!, "10.10 USD")
        XCTAssertEqual(Formatter.usd.string(from: 100.105)!, "100.10 USD")
        XCTAssertEqual(Formatter.usd.string(from: 1000.109)!, "1,000.10 USD")
        XCTAssertEqual(Formatter.usd.string(from: 9999999999999.999)!, "9,999,999,999,999.99 USD")
        XCTAssertEqual(Formatter.usd.string(from: -0.0)!, "-0.00 USD")
        XCTAssertEqual(Formatter.usd.string(from: -10.100)!, "-10.10 USD")
        XCTAssertEqual(Formatter.usd.string(from: -100.105)!, "-100.10 USD")
        XCTAssertEqual(Formatter.usd.string(from: -1000.109)!, "-1,000.10 USD")
        XCTAssertEqual(Formatter.usd.string(from: -9999999999999.999)!, "-9,999,999,999,999.99 USD")
    }

    func testPercent() {
        XCTAssertEqual(Formatter.percent.string(from: 0.0)!, "0.00")
        XCTAssertEqual(Formatter.percent.string(from: 10.100)!, "10.10")
        XCTAssertEqual(Formatter.percent.string(from: 100.105)!, "100.10")
        XCTAssertEqual(Formatter.percent.string(from: 1000.109)!, "1,000.10")
        XCTAssertEqual(Formatter.percent.string(from: 9999999999999.999)!, "9,999,999,999,999.99")
        XCTAssertEqual(Formatter.percent.string(from: -0.0)!, "-0.00")
        XCTAssertEqual(Formatter.percent.string(from: -10.100)!, "-10.10")
        XCTAssertEqual(Formatter.percent.string(from: -100.105)!, "-100.10")
        XCTAssertEqual(Formatter.percent.string(from: -1000.109)!, "-1,000.10")
        XCTAssertEqual(Formatter.percent.string(from: -9999999999999.999)!, "-9,999,999,999,999.99")
    }

    func testShortCrypto() {
        XCTAssertEqual(Formatter.shortCrypto.string(from: 0.0)!, "0.0000")
        XCTAssertEqual(Formatter.shortCrypto.string(from: 10.100)!, "10.1000")
        XCTAssertEqual(Formatter.shortCrypto.string(from: 100.105)!, "100.1050")
        XCTAssertEqual(Formatter.shortCrypto.string(from: 1000.109)!, "1,000.1090")
        XCTAssertEqual(Formatter.shortCrypto.string(from: 999999999999.999)!, "999,999,999,999.9990")
        XCTAssertEqual(Formatter.shortCrypto.string(from: -0.0)!, "-0.0000")
        XCTAssertEqual(Formatter.shortCrypto.string(from: -10.100)!, "-10.1000")
        XCTAssertEqual(Formatter.shortCrypto.string(from: -100.105)!, "-100.1050")
        XCTAssertEqual(Formatter.shortCrypto.string(from: -1000.109)!, "-1,000.1090")
        XCTAssertEqual(Formatter.shortCrypto.string(from: -999999999999.999)!, "-999,999,999,999.9990")
    }

    func testPriceChange() {
        XCTAssertEqual(Formatter.priceChange.string(from: 0.0)!, "+$0.00")
        XCTAssertEqual(Formatter.priceChange.string(from: 10.100)!, "+$10.10")
        XCTAssertEqual(Formatter.priceChange.string(from: 100.105)!, "+$100.10")
        XCTAssertEqual(Formatter.priceChange.string(from: 1000.109)!, "+$1,000.10")
        XCTAssertEqual(Formatter.priceChange.string(from: 9999999999999.999)!, "+$9,999,999,999,999.99")
        XCTAssertEqual(Formatter.priceChange.string(from: -0.0)!, "-$0.00")
        XCTAssertEqual(Formatter.priceChange.string(from: -10.100)!, "-$10.10")
        XCTAssertEqual(Formatter.priceChange.string(from: -100.105)!, "-$100.10")
        XCTAssertEqual(Formatter.priceChange.string(from: -1000.109)!, "-$1,000.10")
        XCTAssertEqual(Formatter.priceChange.string(from: -9999999999999.999)!, "-$9,999,999,999,999.99")
    }

    func testFiat() {
        XCTAssertEqual(Formatter.fiat.string(from: 0.0)!, "$0.00")
        XCTAssertEqual(Formatter.fiat.string(from: 10.100)!, "$10.10")
        XCTAssertEqual(Formatter.fiat.string(from: 100.105)!, "$100.10")
        XCTAssertEqual(Formatter.fiat.string(from: 1000.109)!, "$1,000.10")
        XCTAssertEqual(Formatter.fiat.string(from: 9999999999999.999)!, "$9,999,999,999,999.99")
        XCTAssertEqual(Formatter.fiat.string(from: -0.0)!, "-$0.00")
        XCTAssertEqual(Formatter.fiat.string(from: -10.100)!, "-$10.10")
        XCTAssertEqual(Formatter.fiat.string(from: -100.105)!, "-$100.10")
        XCTAssertEqual(Formatter.fiat.string(from: -1000.109)!, "-$1,000.10")
        XCTAssertEqual(Formatter.fiat.string(from: -9999999999999.999)!, "-$9,999,999,999,999.99")
    }

    func testDefault() {
        XCTAssertEqual(Formatter.default.string(from: 0.0)!, "0")
        XCTAssertEqual(Formatter.default.string(from: 10.1)!, "10")
        XCTAssertEqual(Formatter.default.string(from: 100.50)!, "100")
        XCTAssertEqual(Formatter.default.string(from: 100.51)!, "101")
        XCTAssertEqual(Formatter.default.string(from: 1000.9)!, "1001")
        XCTAssertEqual(Formatter.default.string(from: 9999999999999.999)!, "10000000000000")
        XCTAssertEqual(Formatter.default.string(from: -0.0)!, "-0")
        XCTAssertEqual(Formatter.default.string(from: -10.1)!, "-10")
        XCTAssertEqual(Formatter.default.string(from: -100.50)!, "-100")
        XCTAssertEqual(Formatter.default.string(from: -100.51)!, "-101")
        XCTAssertEqual(Formatter.default.string(from: -1000.9)!, "-1001")
        XCTAssertEqual(Formatter.default.string(from: -9999999999999.999)!, "-10000000000000")
    }

    func testStringCurrency() {
        XCTAssertEqual(Formatter.currencyAccounting.string(from: 0.0)!, "0.00")
        XCTAssertEqual(Formatter.currencyAccounting.string(from: 0.500)!, "0.50")
        XCTAssertEqual(Formatter.currencyAccounting.string(from: 0.505)!, "0.50")
        XCTAssertEqual(Formatter.currencyAccounting.string(from: 0.509)!, "0.50")
        XCTAssertEqual(Formatter.currencyAccounting.string(from: 1000.50)!, "1,000.50")
        XCTAssertEqual(Formatter.currencyAccounting.string(from: 9999999999999.999)!, "9,999,999,999,999.99")
        XCTAssertEqual(Formatter.currencyAccounting.string(from: -0.0)!, "(0.00)")
        XCTAssertEqual(Formatter.currencyAccounting.string(from: -0.500)!, "(0.50)")
        XCTAssertEqual(Formatter.currencyAccounting.string(from: -0.505)!, "(0.50)")
        XCTAssertEqual(Formatter.currencyAccounting.string(from: -0.509)!, "(0.50)")
        XCTAssertEqual(Formatter.currencyAccounting.string(from: -1000.50)!, "(1,000.50)")
        XCTAssertEqual(Formatter.currencyAccounting.string(from: -9999999999999.999)!, "(9,999,999,999,999.99)")
    }

    func testAlternateAmount() {
        XCTAssertEqual(Formatter.alternateAmount.string(from: 0.0)!, "0.0000")
        XCTAssertEqual(Formatter.alternateAmount.string(from: 0.5)!, "0.5000")
        XCTAssertEqual(Formatter.alternateAmount.string(from: 0.05)!, "0.0500")
        XCTAssertEqual(Formatter.alternateAmount.string(from: 0.005)!, "0.0050")
        XCTAssertEqual(Formatter.alternateAmount.string(from: 0.0005)!, "0.0005")
        XCTAssertEqual(Formatter.alternateAmount.string(from: 0.00005)!, "0.0000")
        XCTAssertEqual(Formatter.alternateAmount.string(from: 12341234.12345)!, "12,341,234.1234")
        XCTAssertEqual(Formatter.alternateAmount.string(from: -0.0)!, "-0.0000")
        XCTAssertEqual(Formatter.alternateAmount.string(from: -0.5)!, "-0.5000")
        XCTAssertEqual(Formatter.alternateAmount.string(from: -0.05)!, "-0.0500")
        XCTAssertEqual(Formatter.alternateAmount.string(from: -0.005)!, "-0.0050")
        XCTAssertEqual(Formatter.alternateAmount.string(from: -0.0005)!, "-0.0005")
        XCTAssertEqual(Formatter.alternateAmount.string(from: -0.00005)!, "-0.0000")
        XCTAssertEqual(Formatter.alternateAmount.string(from: -12341234.12345)!, "-12,341,234.1234")
    }

    func testScientificAmount() {
        XCTAssertEqual(Formatter.scientificAmount.string(from: 0.0)!, "0")
        XCTAssertEqual(Formatter.scientificAmount.string(from: 0 as NSNumber)!, "0")
        XCTAssertEqual(Formatter.scientificAmount.string(from: 1.0)!, "1")
        XCTAssertEqual(Formatter.scientificAmount.string(from: 10.0)!, "10")
        XCTAssertEqual(Formatter.scientificAmount.string(from: 100.0)!, "100")
        XCTAssertEqual(Formatter.scientificAmount.string(from: 1000.0)!, "1000")
        XCTAssertEqual(Formatter.scientificAmount.string(from: 12345.0)!, "12345")
        XCTAssertEqual(Formatter.scientificAmount.string(from: 12345.49)!, "12345.49")
        XCTAssertEqual(Formatter.scientificAmount.string(from: 12345.50)!, "12345.5")
        XCTAssertEqual(Formatter.scientificAmount.string(from: 12345.51)!, "12345.51")
        XCTAssertEqual(Formatter.scientificAmount.string(from: -0.0)!, "-0")
        XCTAssertEqual(Formatter.scientificAmount.string(from: -0 as NSNumber)!, "0")
        XCTAssertEqual(Formatter.scientificAmount.string(from: -1.0)!, "-1")
        XCTAssertEqual(Formatter.scientificAmount.string(from: -10.0)!, "-10")
        XCTAssertEqual(Formatter.scientificAmount.string(from: -100.0)!, "-100")
        XCTAssertEqual(Formatter.scientificAmount.string(from: -1000.0)!, "-1000")
        XCTAssertEqual(Formatter.scientificAmount.string(from: -12345.0)!, "-12345")
        XCTAssertEqual(Formatter.scientificAmount.string(from: -12345.49)!, "-12345.49")
        XCTAssertEqual(Formatter.scientificAmount.string(from: -12345.50)!, "-12345.5")
        XCTAssertEqual(Formatter.scientificAmount.string(from: -12345.51)!, "-12345.51")
        XCTAssertEqual(Formatter.scientificAmount.number(from: "1.25E+12")!, 1.25E12)
        XCTAssertEqual(Formatter.scientificAmount.number(from: "-1.25E+12")!, -1.25E12)
        XCTAssertEqual(Formatter.scientificAmount.number(from: "1.25E-12")!, 1.25E-12)
        XCTAssertEqual(Formatter.scientificAmount.number(from: "-1.25E-12")!, -1.25E-12)
    }
}
