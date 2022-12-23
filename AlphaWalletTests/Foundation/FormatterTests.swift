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
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: 0.0)!, "$0.00")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: 10.100)!, "$10.10")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: 100.105)!, "$100.10")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: 1000.109)!, "$1,000.10")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: 9999999999999.999)!, "$9,999,999,999,999.99")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: -0.0)!, "-$0.00")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: -10.100)!, "-$10.10")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: -100.105)!, "-$100.10")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: -1000.109)!, "-$1,000.10")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: -9999999999999.999)!, "-$9,999,999,999,999.99")
        // XCTAssertEqual(Formatters.currency.string(double: 123456789123456789.056), "$123,456,789,123,456,789.05")
    }

    func testUsd() {
        XCTAssertEqual(NumberFormatter.fiat(currency: Currency.USD).string(double: 0.0)!, "0.00 USD")
        XCTAssertEqual(NumberFormatter.fiat(currency: Currency.USD).string(double: 10.100)!, "10.10 USD")
        XCTAssertEqual(NumberFormatter.fiat(currency: Currency.USD).string(double: 100.105)!, "100.10 USD")
        XCTAssertEqual(NumberFormatter.fiat(currency: Currency.USD).string(double: 1000.109)!, "1,000.10 USD")
        XCTAssertEqual(NumberFormatter.fiat(currency: Currency.USD).string(double: 9999999999999.999)!, "9,999,999,999,999.99 USD")
        XCTAssertEqual(NumberFormatter.fiat(currency: Currency.USD).string(double: -0.0)!, "-0.00 USD")
        XCTAssertEqual(NumberFormatter.fiat(currency: Currency.USD).string(double: -10.100)!, "-10.10 USD")
        XCTAssertEqual(NumberFormatter.fiat(currency: Currency.USD).string(double: -100.105)!, "-100.10 USD")
        XCTAssertEqual(NumberFormatter.fiat(currency: Currency.USD).string(double: -1000.109)!, "-1,000.10 USD")
        XCTAssertEqual(NumberFormatter.fiat(currency: Currency.USD).string(double: -9999999999999.999)!, "-9,999,999,999,999.99 USD")
    }

    func testPercent() {
        XCTAssertEqual(NumberFormatter.percent.string(double: 0.0)!, "0.00")
        XCTAssertEqual(NumberFormatter.percent.string(double: 10.100)!, "10.10")
        XCTAssertEqual(NumberFormatter.percent.string(double: 100.105)!, "100.10")
        XCTAssertEqual(NumberFormatter.percent.string(double: 1000.109)!, "1,000.10")
        XCTAssertEqual(NumberFormatter.percent.string(double: 9999999999999.999)!, "9,999,999,999,999.99")
        XCTAssertEqual(NumberFormatter.percent.string(double: -0.0)!, "-0.00")
        XCTAssertEqual(NumberFormatter.percent.string(double: -10.100)!, "-10.10")
        XCTAssertEqual(NumberFormatter.percent.string(double: -100.105)!, "-100.10")
        XCTAssertEqual(NumberFormatter.percent.string(double: -1000.109)!, "-1,000.10")
        XCTAssertEqual(NumberFormatter.percent.string(double: -9999999999999.999)!, "-9,999,999,999,999.99")
    }

    func testShortCrypto() {
        XCTAssertEqual(NumberFormatter.shortCrypto.string(double: 0.0)!, "0.0000")
        XCTAssertEqual(NumberFormatter.shortCrypto.string(double: 10.100)!, "10.1000")
        XCTAssertEqual(NumberFormatter.shortCrypto.string(double: 100.105)!, "100.1050")
        XCTAssertEqual(NumberFormatter.shortCrypto.string(double: 1000.109)!, "1,000.1090")
        XCTAssertEqual(NumberFormatter.shortCrypto.string(double: 999999999999.999)!, "999,999,999,999.9990")
        XCTAssertEqual(NumberFormatter.shortCrypto.string(double: -0.0)!, "-0.0000")
        XCTAssertEqual(NumberFormatter.shortCrypto.string(double: -10.100)!, "-10.1000")
        XCTAssertEqual(NumberFormatter.shortCrypto.string(double: -100.105)!, "-100.1050")
        XCTAssertEqual(NumberFormatter.shortCrypto.string(double: -1000.109)!, "-1,000.1090")
        XCTAssertEqual(NumberFormatter.shortCrypto.string(double: -999999999999.999)!, "-999,999,999,999.9990")
    }

    func testPriceChange() {
        XCTAssertEqual(NumberFormatter.priceChange(currency: .USD).string(double: 0.0)!, "+$0.00")
        XCTAssertEqual(NumberFormatter.priceChange(currency: .USD).string(double: 10.100)!, "+$10.10")
        XCTAssertEqual(NumberFormatter.priceChange(currency: .USD).string(double: 100.105)!, "+$100.10")
        XCTAssertEqual(NumberFormatter.priceChange(currency: .USD).string(double: 1000.109)!, "+$1,000.10")
        XCTAssertEqual(NumberFormatter.priceChange(currency: .USD).string(double: 9999999999999.999)!, "+$9,999,999,999,999.99")
        XCTAssertEqual(NumberFormatter.priceChange(currency: .USD).string(double: -0.0)!, "-$0.00")
        XCTAssertEqual(NumberFormatter.priceChange(currency: .USD).string(double: -10.100)!, "-$10.10")
        XCTAssertEqual(NumberFormatter.priceChange(currency: .USD).string(double: -100.105)!, "-$100.10")
        XCTAssertEqual(NumberFormatter.priceChange(currency: .USD).string(double: -1000.109)!, "-$1,000.10")
        XCTAssertEqual(NumberFormatter.priceChange(currency: .USD).string(double: -9999999999999.999)!, "-$9,999,999,999,999.99")
    }

    func testFiat() {
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: 0.0)!, "$0.00")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: 10.100)!, "$10.10")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: 100.105)!, "$100.10")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: 1000.109)!, "$1,000.10")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: 9999999999999.999)!, "$9,999,999,999,999.99")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: -0.0)!, "-$0.00")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: -10.100)!, "-$10.10")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: -100.105)!, "-$100.10")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: -1000.109)!, "-$1,000.10")
        XCTAssertEqual(NumberFormatter.fiatShort(currency: .USD).string(double: -9999999999999.999)!, "-$9,999,999,999,999.99")
    }

    func testStringCurrency() {
        XCTAssertEqual(NumberFormatter.currencyAccounting.string(double: 0.0)!, "0.00")
        XCTAssertEqual(NumberFormatter.currencyAccounting.string(double: 0.500)!, "0.50")
        XCTAssertEqual(NumberFormatter.currencyAccounting.string(double: 0.505)!, "0.50")
        XCTAssertEqual(NumberFormatter.currencyAccounting.string(double: 0.509)!, "0.50")
        XCTAssertEqual(NumberFormatter.currencyAccounting.string(double: 1000.50)!, "1,000.50")
        XCTAssertEqual(NumberFormatter.currencyAccounting.string(double: 9999999999999.999)!, "9,999,999,999,999.99")
        XCTAssertEqual(NumberFormatter.currencyAccounting.string(double: -0.0)!, "(0.00)")
        XCTAssertEqual(NumberFormatter.currencyAccounting.string(double: -0.500)!, "(0.50)")
        XCTAssertEqual(NumberFormatter.currencyAccounting.string(double: -0.505)!, "(0.50)")
        XCTAssertEqual(NumberFormatter.currencyAccounting.string(double: -0.509)!, "(0.50)")
        XCTAssertEqual(NumberFormatter.currencyAccounting.string(double: -1000.50)!, "(1,000.50)")
        XCTAssertEqual(NumberFormatter.currencyAccounting.string(double: -9999999999999.999)!, "(9,999,999,999,999.99)")
    }

    func testAlternateAmount() {
        XCTAssertEqual(NumberFormatter.alternateAmount.string(double: 0.0)!, "0.0000")
        XCTAssertEqual(NumberFormatter.alternateAmount.string(double: 0.5)!, "0.5000")
        XCTAssertEqual(NumberFormatter.alternateAmount.string(double: 0.05)!, "0.0500")
        XCTAssertEqual(NumberFormatter.alternateAmount.string(double: 0.005)!, "0.0050")
        XCTAssertEqual(NumberFormatter.alternateAmount.string(double: 0.0005)!, "0.0005")
        XCTAssertEqual(NumberFormatter.alternateAmount.string(double: 0.00005)!, "0.0000")
        XCTAssertEqual(NumberFormatter.alternateAmount.string(double: 12341234.12345)!, "12,341,234.1234")
        XCTAssertEqual(NumberFormatter.alternateAmount.string(double: -0.0)!, "-0.0000")
        XCTAssertEqual(NumberFormatter.alternateAmount.string(double: -0.5)!, "-0.5000")
        XCTAssertEqual(NumberFormatter.alternateAmount.string(double: -0.05)!, "-0.0500")
        XCTAssertEqual(NumberFormatter.alternateAmount.string(double: -0.005)!, "-0.0050")
        XCTAssertEqual(NumberFormatter.alternateAmount.string(double: -0.0005)!, "-0.0005")
        XCTAssertEqual(NumberFormatter.alternateAmount.string(double: -0.00005)!, "-0.0000")
        XCTAssertEqual(NumberFormatter.alternateAmount.string(double: -12341234.12345)!, "-12,341,234.1234")
    }

    func testScientificAmount() {
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: 0.0)!, "0")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(from: 0 as NSNumber)!, "0")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: 1.0)!, "1")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: 10.0)!, "10")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: 100.0)!, "100")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: 1000.0)!, "1000")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: 12345.0)!, "12345")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: 12345.49)!, "12345.49")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: 12345.50)!, "12345.5")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: 12345.51)!, "12345.51")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: -0.0)!, "-0")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(from: -0 as NSNumber)!, "0")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: -1.0)!, "-1")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: -10.0)!, "-10")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: -100.0)!, "-100")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: -1000.0)!, "-1000")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: -12345.0)!, "-12345")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: -12345.49)!, "-12345.49")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: -12345.50)!, "-12345.5")
        XCTAssertEqual(NumberFormatter.scientificAmount.string(double: -12345.51)!, "-12345.51")
        XCTAssertEqual(NumberFormatter.scientificAmount.number(from: "1.25E+12")!, 1.25E12)
        XCTAssertEqual(NumberFormatter.scientificAmount.number(from: "-1.25E+12")!, -1.25E12)
        XCTAssertEqual(NumberFormatter.scientificAmount.number(from: "1.25E-12")!, 1.25E-12)
        XCTAssertEqual(NumberFormatter.scientificAmount.number(from: "-1.25E-12")!, -1.25E-12)
    }
}
