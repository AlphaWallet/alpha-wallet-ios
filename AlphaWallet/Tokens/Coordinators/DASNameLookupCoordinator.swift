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
            return .init(error: DASNameLookupError.invalidInput)
        }
        
        let request = EtherServiceRequest(rpcURL: rpcURL, batch: BatchFactory().create(DASLookupRequest(value: value)))
        return Session.send(request).map { response -> AlphaWallet.Address in
            if let record = response.records.first(where: { $0.key == DASNameLookupCoordinator.ethAddressKey }), let address = AlphaWallet.Address(string: record.value) {
                return address
            }
            throw DASNameLookupError.ethRecordNotFound
        }
    }
}
