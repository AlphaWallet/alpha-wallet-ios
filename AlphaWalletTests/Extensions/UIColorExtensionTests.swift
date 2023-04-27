//
//  UIColorExtensionTests.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 4/6/22.
//

import XCTest
@testable import AlphaWallet

class UIColorExtensionTests: XCTestCase {
    func testHexParsing() throws {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        let c1 = UIColor(hex: "ffffff")
        c1.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        XCTAssert(red == 1.0, "\(red)")
        XCTAssert(green == 1.0, "\(green)")
        XCTAssert(blue == 1.0, "\(blue)")
        let c2 = UIColor(hex: "000000")
        c2.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        XCTAssert(red == 0.0, "\(red)")
        XCTAssert(green == 0.0, "\(green)")
        XCTAssert(blue == 0.0, "\(blue)")
        let c3 = UIColor(hex: "123456")
        c3.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        XCTAssert(red*0xff == 0x12, "\(red)")
        XCTAssert(green*0xff == 0x34, "\(green)")
        XCTAssert(blue*0xff == 0x56, "\(blue)")
    }

    func testLightDarkColorMode() throws {
        let lightColor = UIColor(red: 50, green: 100, blue: 150)
        let darkColor = UIColor(red: 10, green: 20, blue: 30)
        let compositeColor = compositeColor(lightColor: lightColor, darkColor: darkColor)
        XCTAssertEqual(compositeColor.lightMode, lightColor)
        XCTAssertEqual(compositeColor.darkMode, darkColor)

    }

    func testDynamicColorDetection() throws {
        let color = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let compositeColor = compositeColor()
        XCTAssertFalse(color.isDynamic)
        XCTAssertTrue(compositeColor.isDynamic)
    }

    func compositeColor(lightColor: UIColor = .yellow, darkColor: UIColor = .green) -> UIColor {
        return UIColor { trait in
            switch trait.userInterfaceStyle {
            case .unspecified, .light:
                return lightColor
            case .dark:
                return darkColor
            }
        }
    }
}
