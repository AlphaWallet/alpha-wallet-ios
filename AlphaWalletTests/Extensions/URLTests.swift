// Copyright © 2021 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet

class URLTests: XCTestCase {
    func testRewrittenIfIpfs() {
        XCTAssertEqual(URL(string: "ipfs://ipfs/QmbZzG343A7JGmHGwnrv3wimHYkB98azcBH1ojzWmVeDty")?.rewrittenIfIpfs.absoluteString, "https://ipfs.io/ipfs/QmbZzG343A7JGmHGwnrv3wimHYkB98azcBH1ojzWmVeDty")
        XCTAssertEqual(URL(string: "ipfs://QmbZzG343A7JGmHGwnrv3wimHYkB98azcBH1ojzWmVeDty")?.rewrittenIfIpfs.absoluteString, "https://ipfs.io/ipfs/QmbZzG343A7JGmHGwnrv3wimHYkB98azcBH1ojzWmVeDty")
        XCTAssertEqual(URL(string: "ipfs://something/QmbZzG343A7JGmHGwnrv3wimHYkB98azcBH1ojzWmVeDty")?.rewrittenIfIpfs.absoluteString, "https://ipfs.io/ipfs/something/QmbZzG343A7JGmHGwnrv3wimHYkB98azcBH1ojzWmVeDty")
        XCTAssertEqual(URL(string: "ipfs://something/something/QmbZzG343A7JGmHGwnrv3wimHYkB98azcBH1ojzWmVeDty")?.rewrittenIfIpfs.absoluteString, "https://ipfs.io/ipfs/something/something/QmbZzG343A7JGmHGwnrv3wimHYkB98azcBH1ojzWmVeDty")
        XCTAssertEqual(URL(string: "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/7")?.rewrittenIfIpfs.absoluteString, "https://ipfs.io/ipfs/QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/7")
    }
}