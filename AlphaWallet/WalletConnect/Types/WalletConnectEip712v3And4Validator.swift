//
//  WalletConnectEip712v3And4Validator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.02.2023.
//

import Foundation
import AlphaWalletCore
import AlphaWalletFoundation

struct WalletConnectEip712v3And4Validator {
    let session: AlphaWallet.WalletConnect.Session
    let source: Analytics.SignMessageRequestSource

    func validate(message: EIP712TypedData) throws {
        if let server = message.server, !session.servers.contains(server) {
            throw SignMessageValidatorError.notMatchesToAnyOfChainIds(active: session.servers, requested: server, source: source)
        }
    }
}
