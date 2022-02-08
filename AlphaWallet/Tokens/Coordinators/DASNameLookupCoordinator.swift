//
//  DASNameLookupCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.10.2021.
//

import JSONRPCKit
import APIKit
import PromiseKit

public final class DASNameLookupCoordinator {
    enum DASNameLookupError: Error {
        case ethRecordNotFound
        case invalidInput
    }

    private static let ethAddressKey = "address.eth"

    static func isValid(value: String) -> Bool {
        return value.trimmed.hasSuffix(".bit")
    }

    func resolve(rpcURL: URL, value: String) -> Promise<AlphaWallet.Address> {
        guard DASNameLookupCoordinator.isValid(value: value) else {
            debugLog("[DAS] Invalid lookup: \(value)")
            return .init(error: DASNameLookupError.invalidInput)
        }

        let request = EtherServiceRequest(rpcURL: rpcURL, batch: BatchFactory().create(DASLookupRequest(value: value)))
        debugLog("[DAS] Looking up value \(value)")
        return Session.send(request).map { response -> AlphaWallet.Address in
            debugLog("[DAS] response for value: \(value) response : \(response)")
            if let record = response.records.first(where: { $0.key == DASNameLookupCoordinator.ethAddressKey }), let address = AlphaWallet.Address(string: record.value) {
                infoLog("[DAS] resolve value: \(value) to address: \(address)")
                return address
            } else if response.records.isEmpty, let ownerAddress = response.ownerAddress {
                infoLog("[DAS] No records fallback value: \(value) to ownerAddress: \(ownerAddress)")
                return ownerAddress
            } else {
                infoLog("[DAS] Can't resolve value: \(value)")
            }
            throw DASNameLookupError.ethRecordNotFound
        }
    }
}