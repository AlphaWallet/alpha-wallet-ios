//
// Created by James Sangalli on 8/11/18.
//
import Foundation
import AlphaWalletENS
import Combine

class EnsResolver: ENSDelegateImpl {
    private let storage: EnsRecordsStorage
    private let server: RPCServer
    private lazy var ens = ENS(delegate: self, chainId: server.chainID)

    init(server: RPCServer, storage: EnsRecordsStorage) {
        self.server = server
        self.storage = storage
    }

    func getENSAddressFromResolver(for name: String) -> AnyPublisher<AlphaWallet.Address, SmartContractError> {
        if let cachedResult = cachedAddressValue(for: name) {
            return .just(cachedResult)
        }

        return ens.getENSAddress(fromName: name)
            .handleEvents(receiveOutput: { [server, storage] address in
                let key = EnsLookupKey(nameOrAddress: name, server: server)
                storage.addOrUpdate(record: .init(key: key, value: .address(address)))
            }).eraseToAnyPublisher()
    }
}

extension EnsResolver: CachebleAddressResolutionServiceType {
    func cachedAddressValue(for name: String) -> AlphaWallet.Address? {
        let key = EnsLookupKey(nameOrAddress: name, server: self.server)
        switch storage.record(for: key, expirationTime: Constants.Ens.recordExpiration)?.value {
        case .address(let address):
            return address
        case .none, .record, .ens:
            return nil
        }
    }
}
