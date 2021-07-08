// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

extension URL {
    var rewrittenIfIpfs: URL {
        if scheme == "ipfs" {
            //We can't use `URLComponents` or `pathComponents` here
            let components = absoluteString.replacingOccurrences(of: "ipfs://", with: "").split(separator: "/")
            if components.count == 1 {
                //Matches doge NFT
                return URL(string: absoluteString.replacingOccurrences(of: "ipfs://", with: "https://ipfs.io/ipfs/")) ?? self
            } else {
                //Matches Alchemy NFT
                return URL(string: absoluteString.replacingOccurrences(of: "ipfs://", with: "https://ipfs.io/")) ?? self
            }
        } else {
            return self
        }
    }
}