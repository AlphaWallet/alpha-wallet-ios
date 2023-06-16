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

    func testEnsureParsingForEas() async throws {
        let url = "https://sepolia.easscan.org/offchain/url/#attestation=eNrFUzmOGzAM%2FItrI%2BBNqsyukU8EKUiJekCQAHl%2BZLvYJp2BDQWoEDSjGYrz%2FQJfyC5XRFQ92%2FUCf97JfOy3G%2FtS4Yj3lsHf8PbmygQ3YmsM1L7cL%2FvkEAi1EmudXE2IhT6Apw0LogQ8JLZqsli0WWR58w7YJONBghhsZhM2JykKaRFwQwdZD53ZK%2FbglYzd3Lhyj3MwdFXGzENCcef5StB7ytvQo508576BEhwqRtxuZAQmdHs8mud9k9lVdYxm4szllSawTGsRxgzNoBGJTQpuS4nFxTEc8WlfzL3miFoIvl0X8EKeW7BRozk21jGhQGsx7vDap18TMyJmrflU8pRdH7LXv2Sv8012GkUUqlc4yMv118%2FffaeAlypeg8N8EQ%2F4H9H3ShFTN2Pb1gRqMmTA55UxMTwWnoh9egmC0Jk67jqZDMkYQeo660xyAe2h4nti9LLqfQITLpg%2Bc1JN2njCicmtXHg6lwNLtu%2FAqOIz5SgyZnUR1iMvPLTPPI97mDvTT5pfdH25wo%2B%2FVjYULA%3D%3D"
        _ = try await Attestation.extract(fromUrlString: url)
    }

    func testEnsureParsingForEasInMagicLink() async throws {
        let url = "http://localhost:3002/?type=eas&id=test%40test.com&secret=0x1592bc27c9c5257dcb5eae2fe7e69fefe91a19afe3d34b317e94cb18d7af7d4c&ticket=eNrFU0uuGzAIvEvWUcXHYFg2L-klqi5sMAeoWqnHfyQ9QhYPWTaSYZixPD8v8I30ckVEkd6uF_j3QTq9bneeKYPNPs5w_oH32xQmuBPrQUM5l2exZ-7kzbgO2FTLcqIuSQdXdzF0UNp0DBwF_cRxqwMLfEUNeIFMmA6xQOciULWTYw0wxZAAt_SSip0rw82ajJb7cZGElJPVTGg-cc5UfGw9Rn5_DM-zbgCGBJM58MHyPWrO--01VE9ktVAJh7OHnsWNiki4XaghVghEFVNCkDmSR6ECEfoc_J_50Dl3s9qJMGs2I07kFoYHxQ5b4TZSAcpkLJu72EbgMrNWFE-Qfn01NR-t_ZW6gXb6vPnz--95zoG3wt5rh3izH-itbnx3PCArfGUIIxMzD5avGD-wl1FV1p4xwjTbXQNyoy7yOZsYnVSUqBWjvPc9Qvro328ythsld0e7umAM0YLK0VYlacMfw2mn5s65RhC5Vm1sxy9fyC5qK99TcLnCr082VwjX"
        _ = try await Attestation.extract(fromUrlString: url)
    }
}
