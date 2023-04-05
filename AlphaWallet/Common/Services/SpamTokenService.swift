//
//  SpamTokenService.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 3/4/23.
//
/// This service subscribes to the AlphaWalletTokensService for add tokens notifications.
/// When a spam token is detected, this service will hide it.

import Foundation
import AlphaWalletFoundation
import Combine

class SpamTokenService {

    private let tokenGroupIdentifier: TokenGroupIdentifierProtocol
    private var cancellableSet = Set<AnyCancellable>()
    private var tokensService: TokensService

    init(tokenGroupIdentifier: TokenGroupIdentifierProtocol, tokensService: TokensService) {
        self.tokenGroupIdentifier = tokenGroupIdentifier
        self.tokensService = tokensService
    }

    func startMonitoring() {
        stopMonitoring()
        tokensService.addedTokensPublisher
            .receive(on: DispatchQueue.main)
            .sink { tokens in
                self.filterSpamTokens(tokens: tokens)
            }
            .store(in: &cancellableSet)
    }

    private func stopMonitoring() {
        cancellableSet.cancellAll()
    }

    private func filterSpamTokens(tokens: [Token]) {
        tokens
            .filter { token in
                tokenGroupIdentifier.isSpam(address: token.contractAddress.eip55String, chainID: token.server.chainID)
            }
            .forEach { token in
                tokensService.mark(token: token, isHidden: true)
            }
    }
}
