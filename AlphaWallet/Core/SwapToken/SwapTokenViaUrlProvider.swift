//
//  SwapTokenViaUrlProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.05.2022.
//

import Foundation

protocol SwapTokenViaUrlProvider: TokenActionProvider {
    var analyticsName: String { get }

    func rpcServer(forToken token: TokenActionsServiceKey) -> RPCServer?
    func url(token: TokenActionsServiceKey) -> URL?
}
