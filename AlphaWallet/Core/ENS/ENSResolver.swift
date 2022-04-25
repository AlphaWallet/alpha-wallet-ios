//
// Created by James Sangalli on 8/11/18.
//
import Foundation
import AlphaWalletENS
import PromiseKit

class ENSResolver: ENSDelegateImpl {

    private static var resultsCache: [ENSLookupKey: AlphaWallet.Address] = [:]
    private (set) var server: RPCServer

    init(server: RPCServer) {
        self.server = server
    }

    func getENSAddressFromResolver(forName name: String) -> Promise<AlphaWallet.Address> {
        if let cachedResult = cachedAddressValue(forName: name) {
            return .value(cachedResult)
        }

        return firstly {
            ENS(delegate: self, chainId: server.chainID).getENSAddress(fromName: name)
        }.get { address in
            Self.cache(forName: name, result: address, server: self.server)
        }
    }

    private func cachedResult(forName name: String) -> AlphaWallet.Address? {
        return ENSResolver.resultsCache[ENSLookupKey(nameOrAddress: name, server: server)]
    }

    private static func cache(forName name: String, result: AlphaWallet.Address, server: RPCServer) {
        ENSResolver.resultsCache[ENSLookupKey(nameOrAddress: name, server: server)] = result
    }
}

extension ENSResolver: CachebleAddressResolutionServiceType {
    func cachedAddressValue(forName name: String) -> AlphaWallet.Address? {
        return cachedResult(forName: name)
    }
}