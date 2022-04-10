//
// Created by James Sangalli on 8/11/18.
//
import Foundation
import AlphaWalletENS
import PromiseKit

class GetENSAddressCoordinator: ENSDelegateImpl {

    private static var resultsCache: [ENSLookupKey: AlphaWallet.Address] = [:]
    private (set) var server: RPCServer

    init(server: RPCServer) {
        self.server = server
    }

    func getENSAddressFromResolver(forName name: String) -> Promise<AlphaWallet.Address> {
        //TODO caching should be based on name instead
        if let cachedResult = cachedAddressValue(forName: name) {
            return .value(cachedResult)
        }

        return firstly {
            ENS(delegate: self, chainId: server.chainID).getENSAddress(fromName: name)
        }.get { address in
            let node = name.lowercased().nameHash
            Self.cache(forNode: node, result: address, server: self.server)
        }
    }

    private func cachedResult(forNode node: String) -> AlphaWallet.Address? {
        return GetENSAddressCoordinator.resultsCache[ENSLookupKey(name: node, server: server)]
    }

    private static func cache(forNode node: String, result: AlphaWallet.Address, server: RPCServer) {
        GetENSAddressCoordinator.resultsCache[ENSLookupKey(name: node, server: server)] = result
    }
}

extension GetENSAddressCoordinator: CachebleAddressResolutionServiceType {
    func cachedAddressValue(forName name: String) -> AlphaWallet.Address? {
        let node = name.lowercased().nameHash
        return cachedResult(forNode: node)
    }
}