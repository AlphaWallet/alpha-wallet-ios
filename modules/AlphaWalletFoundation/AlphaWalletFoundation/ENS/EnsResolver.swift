//
// Created by James Sangalli on 8/11/18.
//
import Foundation
import AlphaWalletENS
import Combine

public class EnsResolver {
    private let storage: DomainNameRecordsStorage
    private let server: RPCServer
    private lazy var ens = ENS(delegate: ensDelegate, chainId: server.chainID)
    private let ensDelegate: ENSDelegateImpl

    public init(storage: DomainNameRecordsStorage, blockchainProvider: BlockchainProvider) {
        self.server = blockchainProvider.server
        self.ensDelegate = ENSDelegateImpl(blockchainProvider: blockchainProvider)
        self.storage = storage
    }

    public func getENSAddressFromResolver(for name: String) -> AnyPublisher<AlphaWallet.Address, SmartContractError> {
        if let cachedResult = cachedAddress(for: name) {
            return .just(cachedResult)
        }

        return ens.getENSAddress(fromName: name)
            .handleEvents(receiveOutput: { [server, storage] address in
                let key = DomainNameLookupKey(nameOrAddress: name, server: server)
                storage.addOrUpdate(record: .init(key: key, value: .address(address)))
            }).eraseToAnyPublisher()
    }
}

extension EnsResolver: CachedDomainNameResolutionServiceType {
    public func cachedAddress(for name: String) -> AlphaWallet.Address? {
        let key = DomainNameLookupKey(nameOrAddress: name, server: self.server)
        switch storage.record(for: key, expirationTime: Constants.DomainName.recordExpiration)?.value {
        case .address(let address):
            return address
        case .none, .record, .domainName:
            return nil
        }
    }
}
