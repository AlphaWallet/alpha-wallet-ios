//
//  SwapTokenNativeProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.05.2022.
//

import Foundation
import Combine

final class SwapTokenNativeProvider: SupportedTokenActionsProvider, TokenActionProvider {
    var objectWillChange: AnyPublisher<Void, Never> {
        return Empty<Void, Never>(completeImmediately: true).eraseToAnyPublisher()
    }

    var action: String { "Swap" }

    func isSupport(token: TokenActionsServiceKey) -> Bool {
        return false
    }

    func actions(token: TokenActionsServiceKey) -> [TokenInstanceAction] {
        return [.init(type: .swap(service: self))]
    }

    func start() {
        //no-op
    }
}
