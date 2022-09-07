//
//  MixpanelCoordinatorTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 26.02.2021.
//

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class MixpanelCoordinatorTests: XCTestCase {
    func testMixpanelSdkTypeConvertation() {
        let coordinator = MixpanelService(withKey: "")
        let values: [AnalyticsEventPropertyValue] = [
            "Hello AlphaWallet",
            1,
            Constants.nullAddress,
            URL(string: Constants.website)!,
            Float(0.0),
            0.0,
            UInt(10)
        ]

        struct UnsuportedValue: AnalyticsEventPropertyValue {
            var value: Any {
                return self
            }
        }

        for value in values {
            let result = coordinator.convertParameterToSdkSpecificVersion(value)
            XCTAssertNotNil(result)
        }

        let unsupportedValue = UnsuportedValue()
        let result = coordinator.convertParameterToSdkSpecificVersion(unsupportedValue)
        XCTAssertNil(result)
    }
}
