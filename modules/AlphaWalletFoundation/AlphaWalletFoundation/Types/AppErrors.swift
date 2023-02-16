//
//  SwapTokenError.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation

public enum SwapTokenError: LocalizedError {
    case swapNotSupported
}

public enum BuyCryptoError: LocalizedError {
    case buyNotSupported
}

public enum ActiveWalletError: LocalizedError {
    case unavailableToResolveSwapActionProvider
    case unavailableToResolveBridgeActionProvider
    case bridgeNotSupported
    case buyNotSupported
    case operationForTokenNotFound
}

public enum WalletApiError: LocalizedError {
    case connectionAddressNotFound
    case requestedWalletNonActive
    case requestedServerDisabled
    case cancelled
}
