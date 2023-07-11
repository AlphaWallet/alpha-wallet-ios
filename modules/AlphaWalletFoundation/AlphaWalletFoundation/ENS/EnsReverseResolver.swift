// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import AlphaWalletENS
import Combine

class EnsReverseResolver {
    private let storage: DomainNameRecordsStorage
    private let server: RPCServer
    private lazy var ens = ENS(delegate: ensDelegate, chainId: server.chainID)
    private let ensDelegate: ENSDelegateImpl

    init(storage: DomainNameRecordsStorage, blockchainProvider: BlockchainProvider) {
        self.server = blockchainProvider.server
        self.storage = storage
        self.ensDelegate = ENSDelegateImpl(blockchainProvider: blockchainProvider)
    }

    //TODO make calls from multiple callers at the same time for the same address more efficient
    func getENSNameFromResolver(for address: AlphaWallet.Address) -> AnyPublisher<String, SmartContractError> {
        if let cachedResult = cachedDomainName(for: address) {
            return .just(cachedResult)
        }

        return ens.getName(fromAddress: address)
            .handleEvents(receiveOutput: { [server, storage] name in
                let key = DomainNameLookupKey(nameOrAddress: address.eip55String, server: server)
                storage.addOrUpdate(record: .init(key: key, value: .domainName(name)))
            }).eraseToAnyPublisher()
    }
}

extension EnsReverseResolver: CachedDomainNameReverseResolutionServiceType {
    func cachedDomainName(for address: AlphaWallet.Address) -> String? {
        let key = DomainNameLookupKey(nameOrAddress: address.eip55String, server: server)
        switch storage.record(for: key, expirationTime: Constants.DomainName.recordExpiration)?.value {
        case .domainName(let ens):
            return ens
        case .none, .record, .address:
            return nil
        }
    }
}
