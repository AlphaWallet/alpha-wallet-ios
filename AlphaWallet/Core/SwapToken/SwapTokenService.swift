//
//  SwapTokenService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.11.2020.
//

import UIKit

protocol SwapTokenActionsService {
    func isSupport(token: TokenObject) -> Bool
    func actions(token: TokenObject) -> [TokenInstanceAction]
}

protocol SwapTokenURLProviderType {
    var action: String { get }
    var rpcServer: RPCServer? { get }
    var analyticsName: String { get }
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
        services.filter {
            $0.isSupport(token: token)
        }.flatMap {
            $0.actions(token: token)
        }
    }

    func isSupport(token: TokenObject) -> Bool {
        return services.compactMap {
            $0.isSupport(token: token) ? $0 : nil
        }.isEmpty
    }

}

