// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

extension URL {
    var rewrittenIfIpfs: URL {
        if scheme == "ipfs" {
            return URL(string: absoluteString.replacingOccurrences(of: "ipfs://", with: "https://ipfs.io/")) ?? self
        } else {
            return self
        }
    }
}