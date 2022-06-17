// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import AlphaWalletENS
import PromiseKit

class EnsReverseResolver: ENSDelegateImpl {
    private let storage: EnsRecordsStorage
    private let server: RPCServer
    private lazy var ens = ENS(delegate: self, chainId: server.chainID)

    init(server: RPCServer, storage: EnsRecordsStorage) {
        self.server = server
        self.storage = storage
    }

    //TODO make calls from multiple callers at the same time for the same address more efficient
    func getENSNameFromResolver(for address: AlphaWallet.Address) -> Promise<String> {
        if let cachedResult = cachedEnsValue(for: address) {
            return .value(cachedResult)
        }

        return firstly {
            ens.getName(fromAddress: address)
        }.get { name in
            let key = EnsLookupKey(nameOrAddress: address.eip55String, server: self.server)
            self.storage.addOrUpdate(record: .init(key: key, value: .ens(name)))
        }
    }
}

extension EnsReverseResolver: CachedEnsResolutionServiceType {
    func cachedEnsValue(for address: AlphaWallet.Address) -> String? {
        let key = EnsLookupKey(nameOrAddress: address.eip55String, server: server)
        switch storage.record(for: key, expirationTime: Constants.Ens.recordExpiration)?.value {
        case .ens(let ens):
            return ens
        case .none, .record, .address:
            return nil
        }
    }
}
