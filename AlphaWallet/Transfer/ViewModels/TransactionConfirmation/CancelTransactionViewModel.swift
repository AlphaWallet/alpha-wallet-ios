//
//  CancelTransactionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2022.
//

import Foundation
import BigInt
import AlphaWalletFoundation

extension TransactionConfirmationViewModel {
    class CancelTransactionViewModel: SectionProtocol, CryptoToFiatRateUpdatable, BalanceUpdatable {
        enum Section {
            case gas
            case network
            case description

            var title: String {
                switch self {
                case .gas:
                    return R.string.localizable.tokenTransactionConfirmationGasTitle()
                case .description:
                    return R.string.localizable.activityCancelDescription()
                case .network:
                    return R.string.localizable.tokenTransactionConfirmationNetwork()
                }
            }

            var isExpandable: Bool { return false }
        }
        private let configurator: TransactionConfigurator
        private var configurationTitle: String {
            return configurator.selectedConfigurationType.title
        }
        let session: WalletSession
        var cryptoToDollarRate: Double?
        var openedSections = Set<Int>()

        var sections: [Section] {
            [.gas, .network, .description]
        }

        init(configurator: TransactionConfigurator) {
            self.configurator = configurator
            self.session = configurator.session
        }

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let configuration: TransactionConfirmationHeaderView.Configuration = .init(isOpened: openedSections.contains(section), section: section, shouldHideChevron: !sections[section].isExpandable)
            let headerName = sections[section].title
            switch sections[section] {
            case .gas:
                let gasFee = gasFeeString(for: configurator, cryptoToDollarRate: cryptoToDollarRate)
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, details: gasFee, configuration: configuration)
                } else {
                    return .init(title: .normal(configurationTitle), headerName: headerName, details: gasFee, configuration: configuration)
                }
            case .description:
                return .init(title: .normal(sections[section].title), headerName: nil, configuration: configuration)
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, configuration: configuration)
            }
        }

        func updateBalance(_ balanceViewModel: BalanceViewModel?) {
            //no-op
        }
    }
}

extension TransactionConfigurationType {
    public var title: String {
        switch self {
        case .standard:
            return R.string.localizable.transactionConfigurationTypeAverage()
        case .slow:
            return R.string.localizable.transactionConfigurationTypeSlow()
        case .fast:
            return R.string.localizable.transactionConfigurationTypeFast()
        case .rapid:
            return R.string.localizable.transactionConfigurationTypeRapid()
        case .custom:
            return R.string.localizable.transactionConfigurationTypeCustom()
        }
    }

    public var estimatedProcessingTime: String {
        switch self {
        case .standard:
            return R.string.localizable.transactionConfigurationTypeAverageTime()
        case .slow:
            return R.string.localizable.transactionConfigurationTypeSlowTime()
        case .fast:
            return R.string.localizable.transactionConfigurationTypeFastTime()
        case .rapid:
            return R.string.localizable.transactionConfigurationTypeRapidTime()
        case .custom:
            return ""
        }
    }
}

extension TransactionConfigurator.GasPriceWarning {
    public var shortTitle: String {
        switch self {
        case .tooHighCustomGasPrice, .networkCongested:
            return R.string.localizable.transactionConfigurationGasPriceTooHighShort()
        case .tooLowCustomGasPrice:
            return R.string.localizable.transactionConfigurationGasPriceTooLowShort()
        }
    }

    var longTitle: String {
        switch self {
        case .tooHighCustomGasPrice, .networkCongested:
            return R.string.localizable.transactionConfigurationGasPriceTooHighLong()
        case .tooLowCustomGasPrice:
            return R.string.localizable.transactionConfigurationGasPriceTooLowLong()
        }
    }

    var description: String {
        switch self {
        case .tooHighCustomGasPrice:
            return R.string.localizable.transactionConfigurationGasPriceTooHighDescription()
        case .networkCongested:
            return R.string.localizable.transactionConfigurationGasPriceCongestedDescription()
        case .tooLowCustomGasPrice:
            return R.string.localizable.transactionConfigurationGasPriceTooLowDescription()
        }
    }
}

extension TransactionConfigurator.GasFeeWarning {
    var description: String {
        ConfigureTransactionError.gasFeeTooHigh.localizedDescription
    }
}

extension ConfigureTransactionError {
    var localizedDescription: String {
        switch self {
        case .gasLimitTooHigh:
            return R.string.localizable.configureTransactionErrorGasLimitTooHigh(ConfigureTransaction.gasLimitMax)
        case .gasFeeTooHigh:
            return R.string.localizable.configureTransactionErrorGasFeeTooHigh(EtherNumberFormatter.short.string(from: BigInt(ConfigureTransaction.gasFeeMax)))
        case .nonceNotPositiveNumber:
            return R.string.localizable.configureTransactionErrorNonceNotPositiveNumber()
        case .gasPriceTooLow:
            return R.string.localizable.configureTransactionErrorGasPriceTooLow()
        case .leaveNonceEmpty:
            return R.string.localizable.configureTransactionErrorLeaveNonceEmpty()
        }
    }
}

extension AddCustomChainError {
    var localizedDescription: String {
        switch self {
        case .cancelled:
            //This is the default behavior, just keep it
            return "\(self)"
        case .missingBlockchainExplorerUrl:
            return R.string.localizable.addCustomChainErrorNoBlockchainExplorerUrl()
        case .invalidBlockchainExplorerUrl:
            return R.string.localizable.addCustomChainErrorInvalidBlockchainExplorerUrl()
        case .noRpcNodeUrl:
            return R.string.localizable.addCustomChainErrorNoRpcNodeUrl()
        case .invalidChainId(let chainId):
            return R.string.localizable.addCustomChainErrorInvalidChainId(chainId)
        case .chainIdNotMatch(let result, let chainId):
            return R.string.localizable.addCustomChainErrorChainIdNotMatch(result, chainId)
        case .unknown(let error):
            return "\(R.string.localizable.addCustomChainErrorUnknown()) — \(error)"
        }
    }
}
