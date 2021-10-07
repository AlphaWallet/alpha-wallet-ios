//
//  GetENSTextRecordsCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.09.2021.
//

import Foundation
import CryptoSwift
import Result
import web3swift
import PromiseKit

enum ENSTextRecord: Equatable, Hashable {
    /// A URL to an image used as an avatar or logo
    case avatar
    /// A description of the name
    case description
    /// A canonical display name for the ENS name; this MUST match the ENS name when its case is folded, and clients should ignore this value if it does not (e.g. "ricmoo.eth" could set this to "RicMoo.eth")
    case display
    /// An e-mail address
    case email
    /// A list of comma-separated keywords, ordered by most significant first; clients that interpresent this field may choose a threshold beyond which to ignore
    case keywords
    /// A physical mailing address
    case mail
    /// A notice regarding this name
    case notice
    /// A generic location (e.g. "Toronto, Canada")
    case location
    /// A phone number as an E.164 string
    case phone
    /// A website URL
    case url

    case custom(String)

    var rawValue: String {
        switch self {
        case .avatar: return "avatar"
        case .description: return "description"
        case .display: return "display"
        case .email: return "email"
        case .keywords: return "keywords"
        case .notice: return "notice"
        case .location: return "location"
        case .phone: return "phone"
        case .url: return "url"
        case .custom(let value): return value
        case .mail: return "mail"
        }
    }
}

/// https://eips.ethereum.org/EIPS/eip-634
final class GetENSTextRecordsCoordinator {
    private struct ENSLookupKey: Hashable {
        let name: String
        let server: RPCServer
        let record: ENSTextRecord
    }

    private static var resultsCache = [ENSLookupKey: String]()

    private (set) var server: RPCServer
    private let ensReverseLookup: ENSReverseLookupCoordinator

    init(server: RPCServer) {
        self.server = server
        ensReverseLookup = ENSReverseLookupCoordinator(server: server)
    }

    func getENSRecord(for address: AlphaWallet.Address, record: ENSTextRecord) -> Promise<String> {
        firstly {
            ensReverseLookup.getENSNameFromResolver(forAddress: address)
        }.then { ens -> Promise<String> in
            self.getENSRecord(for: ens, record: record)
        }
    }

    func getENSRecord(for input: String, record: ENSTextRecord) -> Promise<String> {
        guard !input.components(separatedBy: ".").isEmpty else {
            return .init(error: AnyError(Web3Error(description: "\(input) is invalid ENS name")))
        }
        let addr = input.lowercased().nameHash
        if let cachedResult = cachedResult(forNode: addr, record: record) {
            return .value(cachedResult)
        }

        let function = GetENSTextRecord()
        let server = self.server
        return callSmartContract(withServer: server, contract: server.endRecordsContract, functionName: function.name, abiString: function.abi, parameters: [addr as AnyObject, record.rawValue as AnyObject]).then { result -> Promise<String> in
            guard let record = result["0"] as? String else {
                return .init(error: AnyError(Web3Error(description: "interface doesn't support for server: \(self.server)")))
            }

            if record.isEmpty {
                return .init(error: AnyError(Web3Error(description: "ENS text record not found for record: \(record) for server: \(self.server)")))
            } else {
                return .value(record)
            }
        }.get { value in
            self.cache(forNode: addr, record: record, result: value)
        }
    }

    private func cachedResult(forNode node: String, record: ENSTextRecord) -> String? {
        return GetENSTextRecordsCoordinator.resultsCache[ENSLookupKey(name: node, server: server, record: record)]
    }

    private func cache(forNode node: String, record: ENSTextRecord, result: String) {
        GetENSTextRecordsCoordinator.resultsCache[ENSLookupKey(name: node, server: server, record: record)] = result
    }
}

