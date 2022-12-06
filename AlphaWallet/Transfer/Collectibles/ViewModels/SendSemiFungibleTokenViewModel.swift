//
//  SendSemiFungibleTokenViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit
import AlphaWalletFoundation

final class SendSemiFungibleTokenViewModel {
    let token: Token
    let tokenHolders: [TokenHolder]

    lazy var selectionViewModel: SelectTokenCardAmountViewModel = {
        let availableAmountInt = Int(tokenHolders[0].values.valueIntValue ?? 0)
        let selectedAmount: Int = tokenHolders[0].selectedCount(tokenId: tokenHolders[0].tokenId) ?? 0

        return .init(availableAmount: availableAmountInt, selectedAmount: selectedAmount)
    }()

    let title: String = R.string.localizable.send()

    var assetsHeaderViewModel: SendViewSectionHeaderViewModel {
        let title: String
        switch token.type {
        case .erc1155:
            title = R.string.localizable.semifungiblesSelectedTokens()
        case .erc721, .erc721ForTickets, .erc875:
            title = R.string.localizable.semifungiblesAssetsTitle()
        case .erc20, .nativeCryptocurrency:
            title = ""
        }

        return .init(text: title.uppercased())
    }

    var amountHeaderViewModel: SendViewSectionHeaderViewModel {
        return .init(text: R.string.localizable.sendAmount().uppercased())
    }

    var recipientHeaderViewModel: SendViewSectionHeaderViewModel {
        return .init(text: R.string.localizable.sendRecipient().uppercased(), showTopSeparatorLine: false)
    }

    var isAmountSelectionHidden: Bool {
        switch token.type {
        case .erc1155:
            return tokenHolders.count > 1
        case .nativeCryptocurrency, .erc20, .erc721, .erc721ForTickets, .erc875:
            return true
        }
    }

    init(token: Token, tokenHolders: [TokenHolder]) {
        self.token = token
        self.tokenHolders = tokenHolders
    }

    func updateSelectedAmount(_ value: Int) {
        guard tokenHolders.count == 1 else { return }
        tokenHolders[0].select(with: .token(tokenId: tokenHolders[0].tokenId, amount: value))
    }
}

extension RpcNodeRetryableRequestError {
    public var errorDescription: String? {
        switch self {
        case .possibleBinanceTestnetTimeout:
            //TODO "send transaction" in name?
            return R.string.localizable.sendTransactionErrorPossibleBinanceTestnetTimeout()
        case .rateLimited:
            return R.string.localizable.sendTransactionErrorRateLimited()
        case .networkConnectionWasLost:
            return R.string.localizable.sendTransactionErrorNetworkConnectionWasLost()
        case .invalidCertificate:
            return R.string.localizable.sendTransactionErrorInvalidCertificate()
        case .requestTimedOut:
            return R.string.localizable.sendTransactionErrorRequestTimedOut()
        case .invalidApiKey:
            return R.string.localizable.sendTransactionErrorInvalidKey()
        }
    }
}

extension SwapTokenError {
    var localizedDescription: String {
        switch self {
        case .swapNotSupported:
            return "Swap Not Supported"
        }
    }
}

extension BuyCryptoError {
    var localizedDescription: String {
        switch self {
        case .buyNotSupported:
            return "Buy Crypto Not Supported"
        }
    }
}

extension ActiveWalletError {
    var localizedDescription: String {
        switch self {
        case .unavailableToResolveBridgeActionProvider:
            return "Unavailable To Resolve BridgeActionProvider"
        case .unavailableToResolveSwapActionProvider:
            return "Unavailable To Resolve SwapActionProvider"
        case .bridgeNotSupported:
            return "Bridge Not Supported"
        case .buyNotSupported:
            return "Buy Not Supported"
        case .operationForTokenNotFound:
            return "Operation For Token Not Found"
        }
    }
}

extension WalletApiError {
    var localizedDescription: String {
        switch self {
        case .connectionAddressNotFound:
            return "Connection Address not Found"
        case .requestedWalletNonActive:
            return "Requested Wallet Non Active"
        case .requestedServerDisabled:
            return "Requested Server Is Disabled"
        case .cancelled:
            return "Operation Cancelled"
        }
    }
}

extension DelayWalletConnectResponseError {
    var localizedDescription: String {
        return "Request Rejected! Switch to non watched wallet"
    }
}

extension RequestCanceledDueToWatchWalletError {
    var localizedDescription: String {
        return R.string.localizable.walletConnectFailureMustNotBeWatchedWallet()
    }
}

extension OpenURLError {
    var localizedDescription: String {
        switch self {
        case .unsupportedTokenScriptVersion:
            return R.string.localizable.tokenScriptNotSupportedSchemaError()
        case .copyTokenScriptURL(let url, let destinationFileName, let error):
            return R.string.localizable.tokenScriptMoveFileError(url.path, destinationFileName.path, error.localizedDescription)
        }
    }
}
