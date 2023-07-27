//
//  Enjin.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.10.2021.
//

import Foundation
import Combine
import AlphaWalletCore
import Apollo

public final class Enjin {
    private let server: RPCServer
    private var networking: EnjinNetworking?
    private let storage: EnjinStorage
    private static var sharedNetworking: EnjinNetworking?

    public init(server: RPCServer,
                storage: EnjinStorage,
                accessTokenStore: EnjinAccessTokenStore,
                credentials: EnjinCredentials?) {

        self.storage = storage
        self.server = server

        if let networking = Enjin.sharedNetworking {
            if Enjin.isServerSupported(server) {
                self.networking = networking
            }
        } else {
            Enjin.sharedNetworking = EnjinNetworking(
                accessTokenStore: accessTokenStore,
                credentials: credentials)

            if Enjin.isServerSupported(server) {
                self.networking = Enjin.sharedNetworking
            }
        }
    }

    func token(tokenId: TokenId) async -> EnjinToken? {
        return await storage.getEnjinToken(for: tokenId, server: server)
    }

    public func fetchTokens(wallet: Wallet) -> AnyPublisher<[EnjinToken], PromiseError> {
        guard let networking = networking else { return .just([]) }

        return networking.getEnjinBalances(owner: wallet.address, offset: 1)
            .flatMap { balances in
                let balances = balances.compactMap { EnjinBalance(balance: $0) }
                return networking.getEnjinTokens(balances: balances, owner: wallet.address)
            }.handleEvents(receiveOutput: { [storage, server] response in
                storage.addOrUpdate(enjinTokens: response.tokens, server: server)
            }).map { $0.tokens }
            .eraseToAnyPublisher()
    }

    static func isServerSupported(_ server: RPCServer) -> Bool {
        switch server.serverWithEnhancedSupport {
        case .main:
            return true
        case .xDai, .polygon, .binance_smart_chain, .heco, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, .rinkeby, nil:
            return false
        }
    }
}
