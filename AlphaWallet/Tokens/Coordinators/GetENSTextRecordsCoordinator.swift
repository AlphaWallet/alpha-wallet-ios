//
//  GetENSTextRecordsCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.09.2021.
//

import Foundation
import AlphaWalletENS
import PromiseKit

/// https://eips.ethereum.org/EIPS/eip-634
final class GetENSTextRecordsCoordinator: ENSDelegateImpl {
    private struct ENSLookupKey: Hashable {
        let nameOrAddress: String
        let server: RPCServer
        let record: ENSTextRecordKey

        init(nameOrAddress: String, server: RPCServer, record: ENSTextRecordKey) {
            //Lowercase for case-insensitive lookups
            self.nameOrAddress = nameOrAddress.lowercased()
            self.server = server
            self.record = record
        }
    }

    private static var resultsCache = [ENSLookupKey: String]()

    private (set) var server: RPCServer
    private let ensReverseLookup: ENSReverseLookupCoordinator

    init(server: RPCServer) {
        self.server = server
        ensReverseLookup = ENSReverseLookupCoordinator(server: server)
    }

    func getENSRecord(forAddress address: AlphaWallet.Address, record: ENSTextRecordKey) -> Promise<String> {
        firstly {
            ensReverseLookup.getENSNameFromResolver(forAddress: address)
        }.then { ens -> Promise<String> in
            self.getENSRecord(forName: ens, record: record)
        }
    }

    func getENSRecord(forName name: String, record: ENSTextRecordKey) -> Promise<String> {
        //TODO caching should be based on name instead
        if let cachedResult = cachedResult(forName: name, record: record) {
            return .value(cachedResult)
        }

        return firstly {
            ENS(delegate: self, chainId: server.chainID).getTextRecord(forName: name, recordKey: record)
        }.get { value in
            self.cache(forName: name, record: record, result: value)
        }
    }

    private func cachedResult(forName name: String, record: ENSTextRecordKey) -> String? {
        return GetENSTextRecordsCoordinator.resultsCache[ENSLookupKey(nameOrAddress: name, server: server, record: record)]
    }

    private func cache(forName name: String, record: ENSTextRecordKey, result: String) {
        GetENSTextRecordsCoordinator.resultsCache[ENSLookupKey(nameOrAddress: name, server: server, record: record)] = result
    }
}