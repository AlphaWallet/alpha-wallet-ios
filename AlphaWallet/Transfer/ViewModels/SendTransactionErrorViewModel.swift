// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

struct SendTransactionErrorViewModel {
    let server: RPCServer
    let error: SendTransactionNotRetryableError

    var title: String {
        switch error {
        case .insufficientFunds:
            return R.string.localizable.tokenTransactionConfirmationErrorTitleInsufficientFundsError(server.cryptoCurrencyName)
        case .nonceTooLow:
            return R.string.localizable.tokenTransactionConfirmationErrorTitleNonceTooLowError()
        case .gasPriceTooLow:
            return R.string.localizable.tokenTransactionConfirmationErrorTitleGasPriceTooLow()
        case .gasLimitTooLow:
            return R.string.localizable.tokenTransactionConfirmationErrorTitleGasLimitTooLow()
        case .gasLimitTooHigh:
            return R.string.localizable.tokenTransactionConfirmationErrorTitleGasLimitTooHigh()
        case .possibleChainIdMismatch(let message):
            return message
        case .executionReverted(let message):
            return message
        }
    }

    var description: String {
        switch error {
        case .insufficientFunds:
            return R.string.localizable.tokenTransactionConfirmationErrorDescriptionInsufficientFundsError(server.cryptoCurrencyName, server.symbol, server.symbol, server.cryptoCurrencyName)
        case .nonceTooLow:
            return R.string.localizable.tokenTransactionConfirmationErrorDescriptionNonceTooLowError()
        case .gasPriceTooLow:
            return R.string.localizable.tokenTransactionConfirmationErrorDescriptionGasPriceTooLow()
        case .gasLimitTooLow:
            return R.string.localizable.tokenTransactionConfirmationErrorDescriptionGasLimitTooLow()
        case .gasLimitTooHigh:
            return R.string.localizable.tokenTransactionConfirmationErrorDescriptionGasLimitTooHigh()
        case .possibleChainIdMismatch:
            return R.string.localizable.tokenTransactionConfirmationErrorDescriptionPossibleChainIdMismatchError()
        case .executionReverted:
            return R.string.localizable.tokenTransactionConfirmationErrorDescriptionExecutionRevertedError()
        }
    }

    var linkTitle: String? {
        error.faqEntry?.title
    }

    var linkUrl: URL? {
        error.faqEntry?.url
    }

    var rectifyErrorButtonTitle: String? {
        switch error {
        case .insufficientFunds:
            return R.string.localizable.tokenTransactionConfirmationErrorRectifyButtonTitleInsufficientFundsError(server.symbol)
        case .nonceTooLow:
            return R.string.localizable.tokenTransactionConfirmationErrorRectifyButtonTitleNonceTooLowError()
        case .gasPriceTooLow:
            return R.string.localizable.tokenTransactionConfirmationErrorRectifyButtonTitleGasPriceTooLow()
        case .gasLimitTooLow:
            return R.string.localizable.tokenTransactionConfirmationErrorRectifyButtonTitleGasLimitTooLow()
        case .gasLimitTooHigh:
            return R.string.localizable.tokenTransactionConfirmationErrorRectifyButtonTitleGasLimitTooHigh()
        case .possibleChainIdMismatch:
            return nil
        case .executionReverted:
            return nil
        }
    }

    var backgroundColor: UIColor {
        UIColor.clear
    }

    var footerBackgroundColor: UIColor {
        R.color.white()!
    }
}

extension SendTransactionNotRetryableError {
    var faqEntry: (url: URL, title: String)? {
        switch self {
        case .insufficientFunds:
            return (url: URL(string: "https://alphawallet.com/faq/what-do-insufficient-funds-for-gas-price-mean/")!, title: R.string.localizable.tokenTransactionConfirmationErrorLinkTitleInsufficientFundsError())
        case .nonceTooLow:
            //TODO fill in FAQ URL
            //return (url: URL(string: "")!, title: R.string.localizable.tokenTransactionConfirmationErrorLinkTitleNonceTooLowError())
            return nil
        case .gasPriceTooLow:
            //TODO fill in FAQ URL
            //return (url: URL(string: "")!, title: R.string.localizable.tokenTransactionConfirmationErrorLinkTitleGasPriceTooLow())
            return nil
        case .gasLimitTooLow:
            //TODO fill in FAQ URL
            //return (url: URL(string: "")!, title: R.string.localizable.tokenTransactionConfirmationErrorLinkTitleGasLLow())
            return nil
        case .gasLimitTooHigh:
            //TODO fill in FAQ URL
            //return (url: URL(string: "")!, title: R.string.localizable.tokenTransactionConfirmationErrorLinkTitleGasLimitTooHigh())
            return nil
        case .possibleChainIdMismatch:
            return nil
        case .executionReverted:
            return nil
        }
    }
}
