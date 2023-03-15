//
//  SwapTokenError.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation

public enum SwapTokenError: Error {
    case swapNotSupported
}

public enum BuyCryptoError: Error {
    case buyNotSupported
}

public enum ActiveWalletError: Error {
    case unavailableToResolveSwapActionProvider
    case unavailableToResolveBridgeActionProvider
    case bridgeNotSupported
    case buyNotSupported
    case operationForTokenNotFound
}

public enum WalletApiError: Error {
    case connectionAddressNotFound
    case requestedWalletNonActive
    case requestedServerDisabled
    case cancelled
}
