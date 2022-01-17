// Copyright © 2021 Stormbird PTE. LTD.

@testable import AlphaWallet
import XCTest

class ImportMagicLinkCoordinatorTests: XCTestCase {
    func testHasWalletConnectPathFromSafariExtensionRewriting() {
        let url = URL(string: "https://aw.app/wc:f607884e-63a5-4fa3-8e7d-af6f6fa9b51f@1?bridge=https%3A%2F%2Fn.bridge.walletconnect.org&key=cff9abba23cb9f843e9d623b891a5f8948b41f7d4afc7f7155aa252504cd8264")!
        XCTAssertNotNil(DeepLink.functional.hasWalletConnectPath(in: url))
    }

    func testHasWalletConnectPathFromMobileLinking() {
        let url = URL(string: "https://aw.app/wc?uri=wc%3A588422fd-929d-438a-b337-31c3c9184d9b%401%3Fbridge%3Dhttps%253A%252F%252Fbridge.walletconnect.org%26key%3D8f9459f72aed0790282c47fe45f37ed5cb121bc17795f8f2a229a910bc447202")!
        XCTAssertNotNil(DeepLink.functional.hasWalletConnectPath(in: url))
    }
}
