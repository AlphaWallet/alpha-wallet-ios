// Copyright © 2023 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
@testable import AlphaWalletAttestation
import AlphaWalletWeb3

class AttestationTest: XCTestCase {
    func testIncompleteAddressShouldBeInvalid() {
        XCTAssertEqual(Attestation.functional.extractTypesFromSchemaForTesting("uint256 ticketId,uint256 conferenceId")!, [ABIv2.Element.InOut(name: "ticketId", type: ABIv2.Element.ParameterType.uint(bits: 256)), ABIv2.Element.InOut(name: "conferenceId", type: ABIv2.Element.ParameterType.uint(bits: 256))])
        XCTAssertEqual(Attestation.functional.extractTypesFromSchemaForTesting("uint ticketId,uint256 conferenceId")!, [ABIv2.Element.InOut(name: "ticketId", type: ABIv2.Element.ParameterType.uint(bits: 256)), ABIv2.Element.InOut(name: "conferenceId", type: ABIv2.Element.ParameterType.uint(bits: 256))])
        XCTAssertEqual(Attestation.functional.extractTypesFromSchemaForTesting("uint256 ticketId")!, [ABIv2.Element.InOut(name: "ticketId", type: ABIv2.Element.ParameterType.uint(bits: 256))])
        XCTAssertNil(Attestation.functional.extractTypesFromSchemaForTesting(""))
    }
}
