// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

extension URL {
    var rewriteIfIpfsOrNil: URL? {
        if scheme == "ipfs" {
            //We can't use `URLComponents` or `pathComponents` here
            let path = absoluteString.replacingOccurrences(of: "ipfs://", with: "")
            let urlString: String = {
                if path.hasPrefix("ipfs/") {
                    return "https://alphawallet.infura-ipfs.io/\(path)"
                } else {
                    return "https://alphawallet.infura-ipfs.io/ipfs/\(path)"
                }
            }()
            return URL(string: urlString)
        } else {
            return nil
        }
    }

    public var rewrittenIfIpfs: URL {
        return rewriteIfIpfsOrNil ?? self
    }
}