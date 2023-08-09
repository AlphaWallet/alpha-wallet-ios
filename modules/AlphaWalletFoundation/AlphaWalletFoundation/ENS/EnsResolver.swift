//
// Created by James Sangalli on 8/11/18.
//
import Foundation
import AlphaWalletENS
import Combine

public class EnsResolver {
    private let storage: DomainNameRecordsStorage
    private let server: RPCServer
    private lazy var ens = ENS(delegate: ensDelegate, server: server)
    private let ensDelegate: ENSDelegateImpl

    public init(storage: DomainNameRecordsStorage, blockchainProvider: BlockchainProvider) {
        self.server = blockchainProvider.server
        self.ensDelegate = ENSDelegateImpl(blockchainProvider: blockchainProvider)
        self.storage = storage
    }

    ///TODO speed up by having a default at the caller
    public func getENSAddressFromResolver(for name: String) async throws -> AlphaWallet.Address {
        if Config().development.shouldDisableENSResolution {
            return Constants.nullAddress
        }
        if let cachedResult = await cachedAddress(for: name) {
            return cachedResult
        }
        let address = try await ens.getENSAddress(fromName: name)
        let key = DomainNameLookupKey(nameOrAddress: name, server: server)
        await storage.addOrUpdate(record: .init(key: key, value: .address(address)))
        return address
    }
}

extension EnsResolver: CachedDomainNameResolutionServiceType {
    public func cachedAddress(for name: String) async -> AlphaWallet.Address? {
        let key = DomainNameLookupKey(nameOrAddress: name, server: self.server)
        switch await storage.record(for: key, expirationTime: Constants.DomainName.recordExpiration)?.value {
        case .address(let address):
            return address
        case .none, .record, .domainName:
            return nil
        }
    }
}
