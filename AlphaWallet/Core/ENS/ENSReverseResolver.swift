// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import AlphaWalletENS
import PromiseKit

class ENSReverseResolver: ENSDelegateImpl {
    private static var resultsCache = [ENSLookupKey: String]()

    private let server: RPCServer

    init(server: RPCServer) {
        self.server = server
    }

    //TODO make calls from multiple callers at the same time for the same address more efficient
    func getENSNameFromResolver(forAddress address: AlphaWallet.Address) -> Promise<String> {
        if let cachedResult = cachedEnsValue(forAddress: address) {
            return .value(cachedResult)
        }

        return firstly {
            ENS(delegate: self, chainId: server.chainID).getName(fromAddress: address)
        }.get { name in
            Self.cache(forAddress: address, result: name, server: self.server)
        }
    }

    private func cachedResult(forAddress address: AlphaWallet.Address) -> String? {
        return ENSReverseResolver.resultsCache[ENSLookupKey(nameOrAddress: address.eip55String, server: server)]
    }

    private static func cache(forAddress address: AlphaWallet.Address, result: String, server: RPCServer) {
        ENSReverseResolver.resultsCache[ENSLookupKey(nameOrAddress: address.eip55String, server: server)] = result
    }
}

extension ENSReverseResolver: CachedEnsResolutionServiceType {
    func cachedEnsValue(forAddress address: AlphaWallet.Address) -> String? {
        return cachedResult(forAddress: address)
    }
}