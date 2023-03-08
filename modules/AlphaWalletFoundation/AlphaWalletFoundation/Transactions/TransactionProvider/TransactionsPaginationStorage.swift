//
//  TransactionsPaginationStorage.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 09.03.2023.
//

import Foundation

protocol TransactionsPaginationStorage {
    func transactionsPagination(server: RPCServer, fetchType: TransactionFetchType) -> TransactionsPagination?
    func set(transactionsPagination: TransactionsPagination?, fetchType: TransactionFetchType, server: RPCServer)
}

//TODO: rename maybe with somthing else
public struct WalletConfig {
    private let defaults: UserDefaults

    public init(address: AlphaWallet.Address) {
        self.defaults = UserDefaults(suiteName: address.eip55String)!
    }

    public func clear() {
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { defaults.removeObject(forKey: $0) }
    }
}

extension WalletConfig: TransactionsPaginationStorage {

    private static func transactionsPaginationKey(server: RPCServer, fetchType: TransactionFetchType) -> String {
        return "transactionsPagination-\(server.chainID)-\(fetchType.rawValue)"
    }

    func transactionsPagination(server: RPCServer, fetchType: TransactionFetchType) -> TransactionsPagination? {
        let key = WalletConfig.transactionsPaginationKey(server: server, fetchType: fetchType)

        return defaults.data(forKey: key).flatMap { return try? JSONDecoder().decode(TransactionsPagination.self, from: $0) }
    }

    func set(transactionsPagination: TransactionsPagination?, fetchType: TransactionFetchType, server: RPCServer) {
        let key = WalletConfig.transactionsPaginationKey(server: server, fetchType: fetchType)
        let value = transactionsPagination.flatMap { try? JSONEncoder().encode($0) }
        defaults.set(value, forKey: key)
    }
}
