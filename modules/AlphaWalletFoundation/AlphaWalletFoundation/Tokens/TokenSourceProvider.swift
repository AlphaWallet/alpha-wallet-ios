//
//  TokenSourceProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.07.2022.
//

import Foundation
import Combine

public protocol TokenSourceProvider {
    var session: WalletSession { get }
    var tokensPublisher: AnyPublisher<[Token], Never> { get }
    var addedTokensPublisher: AnyPublisher<[Token], Never> { get }

    func start()
    func refresh()
    func refreshBalance(for tokens: [Token])
    func getTokens() async -> [Token]
}
