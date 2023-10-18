// Copyright © 2023 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
@testable import AlphaWalletAttestation
import AlphaWalletWeb3

class AttestationTest: XCTestCase {
    func testIncompleteAddressShouldBeInvalid() {
        XCTAssertEqual(Attestation.extractTypesFromSchemaForTesting("uint256 ticketId,uint256 conferenceId")!, [ABIv2.Element.InOut(name: "ticketId", type: ABIv2.Element.ParameterType.uint(bits: 256)), ABIv2.Element.InOut(name: "conferenceId", type: ABIv2.Element.ParameterType.uint(bits: 256))])
        XCTAssertEqual(Attestation.extractTypesFromSchemaForTesting("uint ticketId,uint256 conferenceId")!, [ABIv2.Element.InOut(name: "ticketId", type: ABIv2.Element.ParameterType.uint(bits: 256)), ABIv2.Element.InOut(name: "conferenceId", type: ABIv2.Element.ParameterType.uint(bits: 256))])
        XCTAssertEqual(Attestation.extractTypesFromSchemaForTesting("uint256 ticketId")!, [ABIv2.Element.InOut(name: "ticketId", type: ABIv2.Element.ParameterType.uint(bits: 256))])
        XCTAssertNil(Attestation.extractTypesFromSchemaForTesting(""))
    }

    func testEnsureParsingForEasPreMessageVersion1() async throws {
        let url = "https://sepolia.easscan.org/offchain/url/#attestation=eNrFUzmOGzAM%2FItrI%2BBNqsyukU8EKUiJekCQAHl%2BZLvYJp2BDQWoEDSjGYrz%2FQJfyC5XRFQ92%2FUCf97JfOy3G%2FtS4Yj3lsHf8PbmygQ3YmsM1L7cL%2FvkEAi1EmudXE2IhT6Apw0LogQ8JLZqsli0WWR58w7YJONBghhsZhM2JykKaRFwQwdZD53ZK%2FbglYzd3Lhyj3MwdFXGzENCcef5StB7ytvQo508576BEhwqRtxuZAQmdHs8mud9k9lVdYxm4szllSawTGsRxgzNoBGJTQpuS4nFxTEc8WlfzL3miFoIvl0X8EKeW7BRozk21jGhQGsx7vDap18TMyJmrflU8pRdH7LXv2Sv8012GkUUqlc4yMv118%2FffaeAlypeg8N8EQ%2F4H9H3ShFTN2Pb1gRqMmTA55UxMTwWnoh9egmC0Jk67jqZDMkYQeo660xyAe2h4nti9LLqfQITLpg%2Bc1JN2njCicmtXHg6lwNLtu%2FAqOIz5SgyZnUR1iMvPLTPPI97mDvTT5pfdH25wo%2B%2FVjYULA%3D%3D"
        _ = try await Attestation.extract(fromUrlString: url)
    }

    func testEnsureParsingForEasWithVersion1_1() async throws {
        let url = "https://easscan.org/offchain/url/#attestation=eNqlkUGOG0EIRe%2FSaysCCihYtt32JaJZUBR1gFEi5fhTnjlCYIfg%2FQ%2F8PuAX6XHD2wH%2FTiTor3a%2FBxE%2FKT1b6iXx0nZBDRSjR4n1491cygtqOsbqHXjZ9DYspudgHriaCUk33WmzBK0GJaFDcusu%2FA3h1QSCwScRCbhmxFrBsdVmDl%2BSPCCa8Syv1oyoQDrtEhr7OG5kbw6BuJnCFb3LthvV5YmPi%2FIJFyvd7fEsfvw4D4UMLxewaQUjgamsAiQsZzEDKVB23ItZL%2FMtlbioiUbkWN%2BQFCcVRWFA5Ka2917VG7CG075dl3Sf3ouT2GCfqMlABB40K36crPPlfr7GEOkKpyYgTFApx37eO%2Fhj81hq%2F0e3nANhu8GePG5%2FPv%2FWGwH%2FF3hsHn58AWLAf5Y%3D"
        _ = try await Attestation.extract(fromUrlString: url)
    }

    func testEnsureParsingForEasWithVersion1_2() async throws {
        let url = "https://easscan.org/offchain/url/#attestation=eNrFVEuuEzAMvEvXFfIn%2FmT5%2Bsq7BGLh2PEBEEgcn7xyAyqVySJeeDyTyJpvF%2FhCerni9QK%2F35DAPvh2C6LxlXImp94lPpTvsBeK0%2FsWt8tnc%2B8Szcmh1YUBtYomT8FNy61bvQMzVrRkM5av6b5Ie8xdWPkYMjgzA9bOcFsrizAsmZpoExBXeDlgeoU5byRXsQKt0dRjH%2BNkD%2BcEu3PcprAVWWTfQQiANyO2KSmBDro%2FRDd7aLuN3mMqYqHobBllXrUiNlkJ9iyYc5r49ib107G4jXX%2FdT52CglGHc8oOcmnZo8ljHtRZ0dq%2BU7PiCFYLdQQJAHkMuQx5B3U3oRzIomvEGSQOXF%2BBb45vn9MbrG3PB%2BOOslM0OwKh3m5%2Fvzxa3%2BOgOeAz9Hzv6oDjif5%2FiT%2FyfcDnIUdNfBs0hA4NwvDKzEZmZh5HGFlGzjwpfo%2BWPucJDgV2oDXwpF4iJpPiBM%2Fu1%2BsbzoNVI05Tuj9g%2Frl5AF%2B%2FwMoPDxj"
        _ = try await Attestation.extract(fromUrlString: url)
    }

    func testEnsureParsingForEasInMagicLink() async throws {
        let url = "http://localhost:3002/?type=eas&id=test%40test.com&secret=0x1592bc27c9c5257dcb5eae2fe7e69fefe91a19afe3d34b317e94cb18d7af7d4c&ticket=eNrFU0uuGzAIvEvWUcXHYFg2L-klqi5sMAeoWqnHfyQ9QhYPWTaSYZixPD8v8I30ckVEkd6uF_j3QTq9bneeKYPNPs5w_oH32xQmuBPrQUM5l2exZ-7kzbgO2FTLcqIuSQdXdzF0UNp0DBwF_cRxqwMLfEUNeIFMmA6xQOciULWTYw0wxZAAt_SSip0rw82ajJb7cZGElJPVTGg-cc5UfGw9Rn5_DM-zbgCGBJM58MHyPWrO--01VE9ktVAJh7OHnsWNiki4XaghVghEFVNCkDmSR6ECEfoc_J_50Dl3s9qJMGs2I07kFoYHxQ5b4TZSAcpkLJu72EbgMrNWFE-Qfn01NR-t_ZW6gXb6vPnz--95zoG3wt5rh3izH-itbnx3PCArfGUIIxMzD5avGD-wl1FV1p4xwjTbXQNyoy7yOZsYnVSUqBWjvPc9Qvro328ythsld0e7umAM0YLK0VYlacMfw2mn5s65RhC5Vm1sxy9fyC5qK99TcLnCr082VwjX"
        _ = try await Attestation.extract(fromUrlString: url)
    }

    func testEnsureParsingForEasInSmartLayerPassMagicLink() async throws {
        let url = "https://smart-layer.vercel.app/pass?type=eas&ticket=eNrFk0uOHDEIhu9S61bE23g5M5W-RDQLY8MBRomU48fVVyhpwgJbNv4Bi-_XAT_Ijgciqm73OODvB1nr9X5yWyrs_pHS-Ynne1MmOIkt0VHzuIIzqttw4hwllGZzqDRLG0w6tTdRnaDAiwcZ7DDP5rOKR8uCeokgzVEQWwhDHHBEOHfk1ZMwymoRD-aYjIGjtmvTp0k20OBFx4PapSNiuwdw62-6TM9ns3D9SfP0iOe53nYeS1mvpORTGUIbglCfgC6m4oqyK2XDYaEu-958QUTVnFAcHRNtIcBLBG7aJbJ_3zqK-a7jAa-D319_8r683yxu3u0O_-Pry4ayLEElFZl77XsYCb7PNgMM3Fm4se89bi_fl172ZCNabGII-CLRrM8OilXeyteGQYta2cVMtFErBwcHkhSO0bM7EHm0zXsLGJi8No7iF8te2hdTDvHqK6MJcY2VNXEZx1gOhXkXD_j8B3LDA5Y%3D&secret=0x1638d5d84e16749d3daf01795c8cad3adfc9b3b58baa6881246920b840798eed&id=weihong1hu%40shifudao.com"
        _ = try await Attestation.extract(fromUrlString: url)
    }

    //Just to be defensive
    func testEnsureParsingWithAttestationInsteadOfTicketQueryParameterInMagicLink() async throws {
        let url = "https://smart-layer.vercel.app/pass?type=eas&attestation=eNrFk0uOHDEIhu9S61bE23g5M5W-RDQLY8MBRomU48fVVyhpwgJbNv4Bi-_XAT_Ijgciqm73OODvB1nr9X5yWyrs_pHS-Ynne1MmOIkt0VHzuIIzqttw4hwllGZzqDRLG0w6tTdRnaDAiwcZ7DDP5rOKR8uCeokgzVEQWwhDHHBEOHfk1ZMwymoRD-aYjIGjtmvTp0k20OBFx4PapSNiuwdw62-6TM9ns3D9SfP0iOe53nYeS1mvpORTGUIbglCfgC6m4oqyK2XDYaEu-958QUTVnFAcHRNtIcBLBG7aJbJ_3zqK-a7jAa-D319_8r683yxu3u0O_-Pry4ayLEElFZl77XsYCb7PNgMM3Fm4se89bi_fl172ZCNabGII-CLRrM8OilXeyteGQYta2cVMtFErBwcHkhSO0bM7EHm0zXsLGJi8No7iF8te2hdTDvHqK6MJcY2VNXEZx1gOhXkXD_j8B3LDA5Y%3D&secret=0x1638d5d84e16749d3daf01795c8cad3adfc9b3b58baa6881246920b840798eed&id=weihong1hu%40shifudao.com"
        _ = try await Attestation.extract(fromUrlString: url)
    }

    func testEnsureParsingForEasInSmartLayerPassAttestation() async throws {
        let value = "eNrFk0uKGzAMhu-SdSh6WK_lzKS5ROnCluUDlBZ6_FHSIwSmWhhj5O-XhP4fF_hGerkiokgf1wv8_SC1OO83ti2D3T9qBN_x9m7CBDdiLXSUujyS0zdmlK-IhSPHnlDJmWvg9CmmQGmBM_jo8Mwq1YMDZO-0mf8gNjp0dh4dMK6TGHQaAZty79PYM9IQqFpGzLbxMifYdk5gXK7kD05DugdwjTfZKre76XL5Tnnzte63_UY5tcZ-ikYECSymvQAAuQsPHZMwwRllzGJn0jqhYPN0o77ID8xWOWb8hMCL8YD09NUjQFDpCs-H37_-1Ot4f7G4fLU7_I-_HzGFxx4oJKNXEyWGCMHXRTAy8GBhZWPqG3-hOrR_2oUzNIpotC9pmUQl9jykF34oRFtzD6FzxKlN1eM6BrDbVRZqcyFONjg-eZV426XSFntFjVyuosQmm-Y-qph4pkpCAa-Jqw7rq_aAn5_SXALd"
        _ = try await Attestation.extract(fromEncodedValue: value, source: "")
    }
}
