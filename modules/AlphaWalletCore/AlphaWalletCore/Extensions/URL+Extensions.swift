// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

extension URL {
    var rewriteIfIpfsOrNil: URL? {
        var url = self
        let maybeIpfs = absoluteString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if !maybeIpfs.isEmpty && maybeIpfs.range(of: "^[a-zA-Z0-9]+$", options: .regularExpression) != nil {
            url = URL(string: "ipfs://\(maybeIpfs)") ?? url
        }

        if url.scheme == "ipfs" {
            //We can't use `URLComponents` or `pathComponents` here
            let path = url.absoluteString.replacingOccurrences(of: "ipfs://", with: "")
            let urlString: String = {
                if path.hasPrefix("ipfs/") {
                    return "https://alphawallet.infura-ipfs.io/\(path)"
                } else {
                    return "https://alphawallet.infura-ipfs.io/ipfs/\(path)"
                }
            }()
            return URL(string: urlString)
        } else {
            guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
            if components.host == "ipfs.infura.io" {
                components.scheme = "https"
                components.host = "alphawallet.infura-ipfs.io"

                return components.url
            }
            return nil
        }
    }

    public var isIpfs: Bool {
        if scheme == "ipfs" {
            return true
        }
        if host == "alphawallet.infura-ipfs.io" {
            return true
        }
        return false
    }

    public var rewrittenIfIpfs: URL {
        return rewriteIfIpfsOrNil ?? self
    }
}
