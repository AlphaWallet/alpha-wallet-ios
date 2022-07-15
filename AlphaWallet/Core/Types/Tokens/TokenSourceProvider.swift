//
//  TokenSourceProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.07.2022.
//

import Foundation
import Combine

protocol TokenSourceProvider: TokensState, TokenDetectable {
    var session: WalletSession { get }

    func start()
    func refresh()
    func refreshBalance(for tokens: [Token])
    func tokenPublisher(for contract: AlphaWallet.Address) -> AnyPublisher<Token?, Never>
}
