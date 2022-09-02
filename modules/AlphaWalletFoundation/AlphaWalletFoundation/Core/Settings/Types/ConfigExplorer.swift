// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public struct ConfigExplorer {
    private let server: RPCServer

    public init(server: RPCServer) {
        self.server = server
    }

    public func transactionUrl(for ID: String) -> (url: URL, name: String)? {
        let result = ConfigExplorer.explorer(for: server)
        return result.url
            .flatMap { URL(string: $0 + "/tx/" + ID) }
            .flatMap { (url: $0, name: result.name) }
    }

    public func contractUrl(address: AlphaWallet.Address) -> (url: URL, name: String)? {
        let result = ConfigExplorer.explorer(for: server)
        return result.url
            .flatMap { URL(string: $0 + "/address/" + address.eip55String) }
            .flatMap { (url: $0, name: result.name) }
    }

    private static func explorer(for server: RPCServer) -> (url: String?, name: String) {
        let url = server.etherscanWebpageRoot
        return (url?.absoluteString, server.explorerName)
    }
}
