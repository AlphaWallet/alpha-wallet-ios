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
        let name: String
        let server: RPCServer
        let record: ENSTextRecordKey
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
        let addr = name.lowercased().nameHash
        if let cachedResult = cachedResult(forNode: addr, record: record) {
            return .value(cachedResult)
        }

        return firstly {
            ENS(delegate: self, chainId: server.chainID).getTextRecord(forName: name, recordKey: record)
        }.get { value in
            self.cache(forNode: addr, record: record, result: value)
        }
    }

    private func cachedResult(forNode node: String, record: ENSTextRecordKey) -> String? {
        return GetENSTextRecordsCoordinator.resultsCache[ENSLookupKey(name: node, server: server, record: record)]
    }

    private func cache(forNode node: String, record: ENSTextRecordKey, result: String) {
        GetENSTextRecordsCoordinator.resultsCache[ENSLookupKey(name: node, server: server, record: record)] = result
    }
}