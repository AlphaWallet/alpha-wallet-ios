// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

extension URL {
    var rewrittenIfIpfs: URL {
        if scheme == "ipfs" {
            //We can't use `URLComponents` or `pathComponents` here
            let path = absoluteString.replacingOccurrences(of: "ipfs://", with: "")
            let urlString: String = {
                if path.hasPrefix("ipfs/") {
                    return "https://ipfs.io/\(path)"
                } else {
                    return "https://ipfs.io/ipfs/\(path)"
                }
            }()
            return URL(string: urlString) ?? self
        } else {
            return self
        }
    }
}