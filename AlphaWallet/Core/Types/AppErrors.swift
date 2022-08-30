//
//  SwapTokenError.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation

enum SwapTokenError: LocalizedError {
    case swapNotSuppoted
}

enum BuyCryptoError: LocalizedError {
    case buyNotSuppoted
}

enum ActiveWalletError: LocalizedError {
    case unavailableToResolveSwapActionProvider
    case unavailableToResolveBridgeActionProvider
    case bridgeNotSupported
    case buyNotSupported
    case operationForTokenNotFound
}

enum WalletApiError: LocalizedError {
    case connectionAddressNotFound
    case requestedWalletNonActive
    case requestedServerDisabled
    case cancelled
}

struct RequestCanceledDueToWatchWalletError: Error { }
struct DelayWalletConnectResponseError: Error { }
