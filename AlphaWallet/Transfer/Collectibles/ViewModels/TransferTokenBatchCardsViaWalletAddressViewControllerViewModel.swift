//
//  TransferTokenBatchCardsViaWalletAddressViewControllerViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit
import AlphaWalletFoundation

struct TransferTokenBatchCardsViaWalletAddressViewControllerViewModel {
    let token: Token
    let tokenHolders: [TokenHolder]
    var availableAmountInt: Int {
        Int(tokenHolders[0].values.valueIntValue ?? 0)
    }
    var selectedAmount: Int {
        tokenHolders[0].selectedCount(tokenId: tokenHolders[0].tokenId) ?? 0
    }
    lazy var selectionViewModel: SelectTokenCardAmountViewModel = .init(availableAmount: availableAmountInt, selectedAmount: selectedAmount)
    
    var navigationTitle: String {
        R.string.localizable.send()
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var targetAddressAttributedString: NSAttributedString {
        return .init(string: R.string.localizable.aSendRecipientAddressTitle(), attributes: [
            .font: Fonts.regular(size: 13),
            .foregroundColor: R.color.dove()!
        ])
    }

    var isAmountSelectionHidden: Bool {
        tokenHolders.count > 1
    }

    func updateSelectedAmount(_ value: Int) {
        //NOTE: safety check
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
        case .swapNotSuppoted:
            return "Swap Not Suppoted"
        }
    }
}

extension BuyCryptoError {
    var localizedDescription: String {
        switch self {
        case .buyNotSuppoted:
            return "Buy Crypto Not Suppoted"
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

extension KeystoreError {
    public var errorDescription: String? {
        switch self {
        case .failedToDeleteAccount:
            return R.string.localizable.accountsDeleteErrorFailedToDeleteAccount()
        case .failedToDecryptKey:
            return R.string.localizable.accountsDeleteErrorFailedToDecryptKey()
        case .failedToImport(let error):
            return error.localizedDescription
        case .duplicateAccount:
            return R.string.localizable.accountsDeleteErrorDuplicateAccount()
        case .failedToSignTransaction:
            return R.string.localizable.accountsDeleteErrorFailedToSignTransaction()
        case .failedToCreateWallet:
            return R.string.localizable.accountsDeleteErrorFailedToCreateWallet()
        case .failedToImportPrivateKey:
            return R.string.localizable.accountsDeleteErrorFailedToImportPrivateKey()
        case .failedToParseJSON:
            return R.string.localizable.accountsDeleteErrorFailedToParseJSON()
        case .accountNotFound:
            return R.string.localizable.accountsDeleteErrorAccountNotFound()
        case .failedToSignMessage:
            return R.string.localizable.accountsDeleteErrorFailedToSignMessage()
        case .failedToExportPrivateKey:
            return R.string.localizable.accountsDeleteErrorFailedToExportPrivateKey()
        case .failedToExportSeed:
            return R.string.localizable.accountsDeleteErrorFailedToExportSeed()
        case .accountMayNeedImportingAgainOrEnablePasscode:
            return R.string.localizable.keystoreAccessKeyNeedImportOrPasscode()
        case .userCancelled:
            return R.string.localizable.keystoreAccessKeyCancelled()
        }
    }
}
