//
// Created by James Sangalli on 8/11/18.
//
import Foundation
import AlphaWalletENS
import PromiseKit

class EnsResolver: ENSDelegateImpl {
    private let storage: EnsRecordsStorage
    private (set) var server: RPCServer
    private lazy var ens = ENS(delegate: self, chainId: server.chainID)

    init(server: RPCServer, storage: EnsRecordsStorage) {
        self.server = server
        self.storage = storage
    }

    func getENSAddressFromResolver(for name: String) -> Promise<AlphaWallet.Address> {
        if let cachedResult = cachedAddressValue(for: name) {
            return .value(cachedResult)
        }

        return firstly {
            ens.getENSAddress(fromName: name)
        }.get { address in
            let key = EnsLookupKey(nameOrAddress: name, server: self.server)
            self.storage.addOrUpdate(record: .init(key: key, value: .address(address)))
        }
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
