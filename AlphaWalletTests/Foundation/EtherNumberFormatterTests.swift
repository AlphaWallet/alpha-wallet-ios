// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
import AlphaWalletFoundation
import BigInt
import XCTest

class EtherNumberFormatterTests: XCTestCase {
    let fullFormatter = EtherNumberFormatter(locale: Locale(identifier: "en_US_POSIX"))
    let shortFormatter: EtherNumberFormatter = {
        var formatter = EtherNumberFormatter(locale: Locale(identifier: "en_US_POSIX"))
        formatter.maximumFractionDigits = 4
        return formatter
    }()

    func testLessThatZero() {
        XCTAssertEqual(shortFormatter.string(from: BigInt("-10000000000000")), "-0.0000")
        XCTAssertEqual(fullFormatter.string(from: BigInt("-10000000000000")), "-0.00001")
        XCTAssertEqual(fullFormatter.string(from: BigInt("-819947500000000000")), "-0.8199475")
        XCTAssertEqual(shortFormatter.string(from: BigInt("-1000220000000000000")), "-1.0002")
        XCTAssertEqual(shortFormatter.string(from: BigInt("-189000000000000")), "-0.0001")
    }

    func testAbs() {
        XCTAssertEqual(shortFormatter.string(from: BigInt("-189000000000000")), "-0.0001")
        XCTAssertEqual(shortFormatter.string(from: abs(BigInt("-189000000000000"))), "0.0001")
    }

    func testZero() {
        XCTAssertEqual(fullFormatter.string(from: BigInt(0)), "0")
        XCTAssertEqual(shortFormatter.string(from: BigInt(0)), "0")
    }

    func testSmall() {
        XCTAssertEqual(fullFormatter.string(from: BigInt(1)), "0.000000000000000001")
        XCTAssertEqual(shortFormatter.string(from: BigInt(1)), "0.0000")
    }

    func testLarge() {
        XCTAssertEqual(fullFormatter.string(from: BigInt("1000000000000000000"), units: .wei), "1,000,000,000,000,000,000")
        XCTAssertEqual(fullFormatter.string(from: BigInt("100000000000000000"), units: .wei), "100,000,000,000,000,000")
        XCTAssertEqual(fullFormatter.string(from: BigInt("10000000000000000"), units: .wei), "10,000,000,000,000,000")
    }

    func testMinimumFractionDigits2() {
        let formatter3: EtherNumberFormatter = {
            let formatter = EtherNumberFormatter(locale: Locale(identifier: "en_US_POSIX"))
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 4
            return formatter
        }()
        XCTAssertEqual(formatter3.string(from: BigInt("819947500000000000")!), "0.81")
    }

    func testMinimumFractionDigits() {
        let formatter1: EtherNumberFormatter = {
            let formatter = EtherNumberFormatter(locale: Locale(identifier: "en_US_POSIX"))
            formatter.minimumFractionDigits = 3
            formatter.maximumFractionDigits = 3
            return formatter
        }()
        XCTAssertEqual(formatter1.string(from: BigInt(1)), "0.000")

        let formatter2: EtherNumberFormatter = {
            let formatter = EtherNumberFormatter(locale: Locale(identifier: "en_US_POSIX"))
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 4
            return formatter
        }()
        XCTAssertEqual(formatter2.string(from: BigInt(1)), "0.0000")
    }

    func testDigits() {
        let number = BigInt("1234567890123456789012345678901")!
        XCTAssertEqual(fullFormatter.string(from: number), "1,234,567,890,123.456789012345678901")
        XCTAssertEqual(shortFormatter.string(from: number), "1,234,567,890,123.4567")
    }

    func testDigits2() {
        let number = BigInt("819947500000000000")!
        XCTAssertEqual(shortFormatter.string(from: number), "0.8199")
    }

    func testDigits3() {
        let number = BigInt("165700487753527")!
        XCTAssertEqual(shortFormatter.string(from: number), "0.0001")
    }

    func testNoFraction() {
        let formatter: EtherNumberFormatter = {
            let formatter = EtherNumberFormatter(locale: Locale(identifier: "en_US_POSIX"))
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
            return formatter
        }()
        let number = BigInt("1000000000000000")!
        XCTAssertEqual(formatter.string(from: number), "0")
    }

    func testNegative() {
        let number = BigInt("-437258644730000000000")!
        XCTAssertEqual(fullFormatter.string(from: number), "-437.25864473")
        XCTAssertEqual(shortFormatter.string(from: number), "-437.2586")
    }

    func testRound() {
        let number = BigInt("123456789012345678901")!
        XCTAssertEqual(shortFormatter.string(from: number), "123.4567")
    }

    func testRoundNegative() {
        let number = BigInt("-123456789012345678901")!
        XCTAssertEqual(shortFormatter.string(from: number), "-123.4567")
    }

    func testDecimals() {
        let number = BigInt("987654321")!
        XCTAssertEqual(shortFormatter.string(from: number, decimals: 4), "98,765.4321")
    }

    func testFractionalToNumber() {
        let input = "0.123456789012345678"
        XCTAssertEqual(fullFormatter.number(from: input)?.description, "123456789012345678")
    }

    func testLargeNumber() {
        let input = "1234567890123456789012345678901.123456789012345678"
        XCTAssertEqual(fullFormatter.number(from: input)?.description, "1234567890123456789012345678901123456789012345678")
    }

    func testUnrepresentableNumber() {
        let input = "0.123456789012345678901"
        XCTAssertNil(fullFormatter.number(from: input))
    }

    func testInvalidNumber() {
        let input = "A0.190268247.487754"
        XCTAssertNil(fullFormatter.number(from: input))
    }

    func testMinMaxFormattedNumber() {
        Config.setLocale(.english)

        let locale: Locale = Config.locale

        func fiatFormatter(usesGroupingSeparator: Bool = false, currency: Currency) -> NumberFormatter {
            let formatter = NumberFormatter.currencyAccounting
            formatter.locale = locale
            formatter.currencyCode = currency.code
            formatter.usesGroupingSeparator = usesGroupingSeparator

            return formatter
        }

        let formatter = fiatFormatter(usesGroupingSeparator: true, currency: .USD)

        XCTAssertEqual(formatter.string(double: 0.00001234234, minimumFractionDigits: 2, maximumFractionDigits: 6), "0.000012")
        XCTAssertEqual(formatter.string(double: 0.043, minimumFractionDigits: 2, maximumFractionDigits: 6), "0.04")
        XCTAssertEqual(formatter.string(double: 12.043, minimumFractionDigits: 2, maximumFractionDigits: 6), "12.04")
        XCTAssertEqual(formatter.string(double: 1, minimumFractionDigits: 2, maximumFractionDigits: 6), "1.00")
        XCTAssertEqual(formatter.string(double: 0.1213123123123, minimumFractionDigits: 2, maximumFractionDigits: 6), "0.12")
        XCTAssertEqual(formatter.string(double: 1111102222.1213123123123, minimumFractionDigits: 2, maximumFractionDigits: 6), "1,111,102,222.12")

        Config.setLocale(.system)
    }
}
