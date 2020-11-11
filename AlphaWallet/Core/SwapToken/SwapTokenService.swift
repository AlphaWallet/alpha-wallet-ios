//
//  SwapTokenService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.11.2020.
//

import UIKit

protocol SwapTokenActionsService {
    func actions(token: TokenObject) -> [TokenInstanceAction]
}

extension SwapTokenActionsService {
    func isSupportToken(token: TokenObject) -> Bool {
        return !actions(token: token).isEmpty
    }
}

protocol SwapTokenURLProviderType {
    var action: String { get }

    func url(token: TokenObject) -> URL?
}

protocol SwapTokenServiceType: SwapTokenActionsService {
    func register(service: SwapTokenActionsService)
}

class SwapTokenService: SwapTokenServiceType {

    private var services: [SwapTokenActionsService] = []

    func register(service: SwapTokenActionsService) {
        services.append(service)
    }

    func actions(token: TokenObject) -> [TokenInstanceAction] {
        let values = services.flatMap {
            $0.actions(token: token)
        }
        return values
    }
}

