// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import AlphaWalletENS
import Combine

class EnsReverseResolver {
    private let storage: DomainNameRecordsStorage
    private let server: RPCServer
    private lazy var ens = ENS(delegate: ensDelegate, server: server)
    private let ensDelegate: ENSDelegateImpl

    init(storage: DomainNameRecordsStorage, blockchainProvider: BlockchainProvider) {
        self.server = blockchainProvider.server
        self.storage = storage
        self.ensDelegate = ENSDelegateImpl(blockchainProvider: blockchainProvider)
    }

    //TODO make calls from multiple callers at the same time for the same address more efficient
    ///TODO speed up by having a default at the caller
    func getENSNameFromResolver(for address: AlphaWallet.Address) async throws -> String {
        if Config().development.shouldDisableENSResolution {
            return "fake"
        }
        if let cachedResult = await cachedDomainName(for: address) {
            return cachedResult
        }
        let name = try await ens.getName(fromAddress: address)
        let key = DomainNameLookupKey(nameOrAddress: address.eip55String, server: server)
        await storage.addOrUpdate(record: .init(key: key, value: .domainName(name)))
        return name
    }
}

extension EnsReverseResolver: CachedDomainNameReverseResolutionServiceType {
    func cachedDomainName(for address: AlphaWallet.Address) async -> String? {
        let key = DomainNameLookupKey(nameOrAddress: address.eip55String, server: server)
        switch await storage.record(for: key, expirationTime: Constants.DomainName.recordExpiration)?.value {
        case .domainName(let ens):
            return ens
        case .none, .record, .address:
            return nil
        }
    }
}
