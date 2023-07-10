//
//  SendSemiFungibleTokenViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit
import AlphaWalletFoundation
import enum AlphaWalletTokenScript.OpenURLError
import Combine

final class SendSemiFungibleTokenViewModel {
    let token: Token
    let tokenHolders: [TokenHolder]

    lazy var selectionViewModel: SelectAssetViewModel = {
        let available = Int(tokenHolders[0].values.valueIntValue ?? 1)
        let selected: Int = tokenHolders[0].selectedCount(tokenId: tokenHolders[0].tokenId) ?? 0

        return SelectAssetViewModel(available: available, selected: selected)
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
    private var cancellable = Set<AnyCancellable>()

    init(token: Token, tokenHolders: [TokenHolder]) {
        self.token = token
        self.tokenHolders = tokenHolders
    }

    func transform() {
        selectionViewModel.selected
            .filter { [weak self] _ in self?.tokenHolders.count == 1 }
            .sink { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.tokenHolders[0].select(with: .token(tokenId: strongSelf.tokenHolders[0].tokenId, amount: $0))
            }.store(in: &cancellable)
    }
}

extension RpcNodeRetryableRequestError: LocalizedError {
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

extension SwapTokenError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .swapNotSupported:
            return "Swap Not Supported"
        }
    }
}

extension BuyCryptoError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .buyNotSupported:
            return "Buy Crypto Not Supported"
        }
    }
}

extension ActiveWalletError: LocalizedError {
    public var errorDescription: String? {
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

extension WalletApiError: LocalizedError {
    public var errorDescription: String? {
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

extension OpenURLError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedTokenScriptVersion:
            return R.string.localizable.tokenScriptNotSupportedSchemaError()
        case .copyTokenScriptURL(let url, let destinationFileName, let error):
            return R.string.localizable.tokenScriptMoveFileError(url.path, destinationFileName.path, error.localizedDescription)
        }
    }
}
