//
//  SwapTokenViaUrlProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.05.2022.
//

import Foundation

public protocol SwapTokenViaUrlProvider: TokenActionProvider {
    var analyticsName: String { get }

    func rpcServer(forToken token: TokenActionsIdentifiable) -> RPCServer?
    func url(token: TokenActionsIdentifiable) -> URL?
}
