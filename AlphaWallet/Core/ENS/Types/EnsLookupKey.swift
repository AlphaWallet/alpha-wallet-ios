//
//  EnsLookupKey.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 06.06.2022.
//

import Foundation
import AlphaWalletENS

struct EnsLookupKey: Hashable, CustomStringConvertible {
    let nameOrAddress: String
    let server: RPCServer
    let record: EnsTextRecordKey?

    init(nameOrAddress: String, server: RPCServer) {
        //Lowercase for case-insensitive lookups
        self.nameOrAddress = nameOrAddress.lowercased()
        self.server = server
        self.record = nil
    }

    init(nameOrAddress: String, server: RPCServer, record: EnsTextRecordKey) {
        //Lowercase for case-insensitive lookups
        self.nameOrAddress = nameOrAddress.lowercased()
        self.server = server
        self.record = record
    }

    var description: String {
        return [nameOrAddress, String(server.chainID), record?.rawValue].compactMap { $0 }.joined(separator: "-")
    }
}
