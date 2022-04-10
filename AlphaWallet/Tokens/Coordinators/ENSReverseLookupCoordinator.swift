// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import AlphaWalletENS
import PromiseKit

class ENSReverseLookupCoordinator: CachedEnsResolutionServiceType, ENSDelegateImpl {
    private static var resultsCache = [ENSLookupKey: String]()

    private let server: RPCServer

    init(server: RPCServer) {
        self.server = server
    }

    func cachedEnsValue(for input: AlphaWallet.Address) -> String? {
        let node = input.nameHash
        return cachedResult(forNode: node)
    }

    //TODO make calls from multiple callers at the same time for the same address more efficient
    func getENSNameFromResolver(forAddress input: AlphaWallet.Address) -> Promise<String> {
        //TODO caching should be based on input instead
        if let cachedResult = cachedEnsValue(for: input) {
            return .value(cachedResult)
        }

        return firstly {
            ENS(delegate: self, chainId: server.chainID).getName(fromAddress: input)
        }.get { name in
            let node = input.nameHash
            Self.cache(forNode: node, result: name, server: self.server)
        }
    }

    private func cachedResult(forNode node: String) -> String? {
        return ENSReverseLookupCoordinator.resultsCache[ENSLookupKey(name: node, server: server)]
    }

    private static func cache(forNode node: String, result: String, server: RPCServer) {
        ENSReverseLookupCoordinator.resultsCache[ENSLookupKey(name: node, server: server)] = result
    }
}