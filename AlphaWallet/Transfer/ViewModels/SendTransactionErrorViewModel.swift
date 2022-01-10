// Copyright © 2021 Stormbird PTE. LTD.

import UIKit

struct SendTransactionErrorViewModel {
    let server: RPCServer
    let error: SendTransactionNotRetryableError

    var title: String {
        switch error {
        case .insufficientFunds:
            return R.string.localizable.tokenTransactionConfirmationErrorTitleInsufficientFundsError(server.cryptoCurrencyName)
        case .nonceTooLow:
            return R.string.localizable.tokenTransactionConfirmationErrorTitleNonceTooLowError(preferredLanguages: Languages.preferred())
        case .gasPriceTooLow:
            return R.string.localizable.tokenTransactionConfirmationErrorTitleGasPriceTooLow(preferredLanguages: Languages.preferred())
        case .gasLimitTooLow:
            return R.string.localizable.tokenTransactionConfirmationErrorTitleGasLimitTooLow(preferredLanguages: Languages.preferred())
        case .gasLimitTooHigh:
            return R.string.localizable.tokenTransactionConfirmationErrorTitleGasLimitTooHigh(preferredLanguages: Languages.preferred())
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
            return R.string.localizable.tokenTransactionConfirmationErrorDescriptionNonceTooLowError(preferredLanguages: Languages.preferred())
        case .gasPriceTooLow:
            return R.string.localizable.tokenTransactionConfirmationErrorDescriptionGasPriceTooLow(preferredLanguages: Languages.preferred())
        case .gasLimitTooLow:
            return R.string.localizable.tokenTransactionConfirmationErrorDescriptionGasLimitTooLow(preferredLanguages: Languages.preferred())
        case .gasLimitTooHigh:
            return R.string.localizable.tokenTransactionConfirmationErrorDescriptionGasLimitTooHigh(preferredLanguages: Languages.preferred())
        case .possibleChainIdMismatch:
            return R.string.localizable.tokenTransactionConfirmationErrorDescriptionPossibleChainIdMismatchError(preferredLanguages: Languages.preferred())
        case .executionReverted:
            return R.string.localizable.tokenTransactionConfirmationErrorDescriptionExecutionRevertedError(preferredLanguages: Languages.preferred())
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
            return R.string.localizable.tokenTransactionConfirmationErrorRectifyButtonTitleNonceTooLowError(preferredLanguages: Languages.preferred())
        case .gasPriceTooLow:
            return R.string.localizable.tokenTransactionConfirmationErrorRectifyButtonTitleGasPriceTooLow(preferredLanguages: Languages.preferred())
        case .gasLimitTooLow:
            return R.string.localizable.tokenTransactionConfirmationErrorRectifyButtonTitleGasLimitTooLow(preferredLanguages: Languages.preferred())
        case .gasLimitTooHigh:
            return R.string.localizable.tokenTransactionConfirmationErrorRectifyButtonTitleGasLimitTooHigh(preferredLanguages: Languages.preferred())
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
            return (url: URL(string: "https://alphawallet.com/faq/what-do-insufficient-funds-for-gas-price-mean/")!, title: R.string.localizable.tokenTransactionConfirmationErrorLinkTitleInsufficientFundsError(preferredLanguages: Languages.preferred()))
        case .nonceTooLow:
            //TODO fill in FAQ URL
            //return (url: URL(string: "")!, title: R.string.localizable.tokenTransactionConfirmationErrorLinkTitleNonceTooLowError(preferredLanguages: Languages.preferred()))
            return nil
        case .gasPriceTooLow:
            //TODO fill in FAQ URL
            //return (url: URL(string: "")!, title: R.string.localizable.tokenTransactionConfirmationErrorLinkTitleGasPriceTooLow(preferredLanguages: Languages.preferred()))
            return nil
        case .gasLimitTooLow:
            //TODO fill in FAQ URL
            //return (url: URL(string: "")!, title: R.string.localizable.tokenTransactionConfirmationErrorLinkTitleGasLLow(preferredLanguages: Languages.preferred()))
            return nil
        case .gasLimitTooHigh:
            //TODO fill in FAQ URL
            //return (url: URL(string: "")!, title: R.string.localizable.tokenTransactionConfirmationErrorLinkTitleGasLimitTooHigh(preferredLanguages: Languages.preferred()))
            return nil
        case .possibleChainIdMismatch:
            return nil
        case .executionReverted:
            return nil
        }
    }
}
