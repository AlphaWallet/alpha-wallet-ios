// Copyright © 2021 Stormbird PTE. LTD.

@testable import AlphaWallet
import XCTest
@testable import AlphaWalletFoundation

class DeepLinkTests: XCTestCase {
    func testHasWalletConnectPathFromSafariExtensionRewriting() {
        let url = URL(string: "https://aw.app/wc:f607884e-63a5-4fa3-8e7d-af6f6fa9b51f@1?bridge=https%3A%2F%2Fn.bridge.walletconnect.org&key=cff9abba23cb9f843e9d623b891a5f8948b41f7d4afc7f7155aa252504cd8264")!
        XCTAssertNotNil(DeepLink.functional.extractWalletConnectUrlMaybeEmbedded(in: url))
    }

    func testHasWalletConnectPathFromMobileLinking() {
        let url = URL(string: "https://aw.app/wc?uri=wc%3A588422fd-929d-438a-b337-31c3c9184d9b%401%3Fbridge%3Dhttps%253A%252F%252Fbridge.walletconnect.org%26key%3D8f9459f72aed0790282c47fe45f37ed5cb121bc17795f8f2a229a910bc447202")!
        XCTAssertNotNil(DeepLink.functional.extractWalletConnectUrlMaybeEmbedded(in: url))

        let url2 = URL(string: "awallet://wc?uri=wc%3A5f577f99-2f54-40f7-9463-7ff640772090%401%3Fbridge%3Dhttps%253A%252F%252Fwalletconnect.depay.com%26key%3D1938aa2c9d4104c91cbc60e94631cf769c96ebad1ea2fc30e18ba09e39bc3c0b")!
        XCTAssertNotNil(DeepLink.functional.extractWalletConnectUrlMaybeEmbedded(in: url2))
    }

    func testWalletApiUrl() {
        guard let url = URL(string: "https://aw.app/wallet/v1/connect?redirecturl=https%3A%2F%2Fmyapp.com&metadata=%7B%22name%22%3A%22Some%20app%22%2C%22iconurl%22%3A%22https%3A%2F%2Fimg.icons8.com%2Fnolan%2F344%2Fethereum.png%22%2C%20%22appurl%22%3A%20%22https%3A%2F%2Funiswap.org%2F%22%2C%20%22note%22%3A%22This%20will%20inform%20them%20your%20wallet%20address%20is%200x2322%E2%80%A62324%22%7D") else {
            return XCTFail()
        }

        guard case .walletApi(let api) = DeepLink(url: url) else {
            return XCTFail()
        }

        switch api {
        case let .connect(redirectUrl, version, _):
            XCTAssertEqual(redirectUrl.absoluteString, "https://myapp.com")
            XCTAssertEqual(version, "v1")
        case .signPersonalMessage:
            XCTFail()
        }
    }
}
