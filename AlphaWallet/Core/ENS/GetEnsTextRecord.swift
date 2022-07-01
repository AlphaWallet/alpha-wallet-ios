//
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.09.2021.
//

import Foundation
import AlphaWalletENS
import PromiseKit
import Combine

/// https://eips.ethereum.org/EIPS/eip-634
final class GetEnsTextRecord: ENSDelegateImpl {
    private let storage: EnsRecordsStorage
    private lazy var ens = ENS(delegate: self, chainId: server.chainID)
    private let server: RPCServer
    private let ensReverseLookup: EnsReverseResolver

    init(server: RPCServer, storage: EnsRecordsStorage) {
        self.server = server
        self.storage = storage
        ensReverseLookup = EnsReverseResolver(server: server, storage: storage)
    }

    func getENSRecord(forAddress address: AlphaWallet.Address, record: EnsTextRecordKey) -> AnyPublisher<String, SmartContractError> {
        ensReverseLookup.getENSNameFromResolver(for: address)
            .flatMap { ens in
                self.getENSRecord(forName: ens, record: record)
            }.eraseToAnyPublisher()
    }

    func getENSRecord(forName name: String, record: EnsTextRecordKey) -> AnyPublisher<String, SmartContractError> {
        if let cachedResult = cachedResult(forName: name, record: record) {
            return .just(cachedResult)
        }

        return ens.getTextRecord(forName: name, recordKey: record)
            .handleEvents(receiveOutput: { [storage, server] value in
                let key = EnsLookupKey(nameOrAddress: name, server: server, record: record)
                storage.addOrUpdate(record: .init(key: key, value: .record(value)))
            }).eraseToAnyPublisher()
    }

    private func cachedResult(forName name: String, record: EnsTextRecordKey) -> String? {
        let key = EnsLookupKey(nameOrAddress: name, server: server, record: record)
        switch storage.record(for: key, expirationTime: Constants.Ens.recordExpiration)?.value {
        case .record(let record):
            return record
        case .ens, .address, .none:
            return nil
        }
    }
}
