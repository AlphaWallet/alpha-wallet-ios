//
//  DappOrWalletConnectTransactionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2022.
//

import UIKit
import BigInt
import AlphaWalletFoundation

extension TransactionConfirmationViewModel {
    class DappOrWalletConnectTransactionViewModel: SectionProtocol, CryptoToFiatRateUpdatable, BalanceUpdatable {
        enum Section {
            case balance
            case gas
            case network
            case amount
            case recipient
            case function(DecodedFunctionCall)

            var title: String {
                switch self {
                case .network:
                    return R.string.localizable.tokenTransactionConfirmationNetwork()
                case .gas:
                    return R.string.localizable.tokenTransactionConfirmationGasTitle()
                case .amount:
                    return R.string.localizable.transactionConfirmationSendSectionAmountTitle()
                case .function:
                    return R.string.localizable.tokenTransactionConfirmationFunctionTitle()
                case .balance:
                    return R.string.localizable.transactionConfirmationSendSectionBalanceTitle()
                case .recipient:
                    return R.string.localizable.transactionConfirmationSendSectionRecipientTitle()
                }
            }

            var isExpandable: Bool {
                switch self {
                case .gas, .amount, .network, .balance:
                    return false
                case .function, .recipient:
                    return true
                }
            }
        }

        private var balance: String?
        private var newBalance: String?
        private let configurator: TransactionConfigurator
        private var configurationTitle: String {
            return configurator.selectedConfigurationType.title
        }
        private var requester: RequesterViewModel?
        private let assetDefinitionStore: AssetDefinitionStore
        private var formattedAmountValue: String {
            let cryptoToDollarSymbol = Constants.Currency.usd
            let amount = Double(configurator.transaction.value) / Double(EthereumUnit.ether.rawValue)
            let amountString = EtherNumberFormatter.full.string(from: configurator.transaction.value)
            let symbol = configurator.session.server.symbol
            if let cryptoToDollarRate = cryptoToDollarRate {
                let cryptoToDollarValue = StringFormatter().currency(with: amount * cryptoToDollarRate, and: cryptoToDollarSymbol)
                return "\(amountString) \(symbol) ≈ \(cryptoToDollarValue) \(cryptoToDollarSymbol)"
            } else {
                return "\(amountString) \(symbol)"
            }
        }
        private let recipientResolver: RecipientResolver
        let session: WalletSession
        let functionCallMetaData: DecodedFunctionCall?
        var cryptoToDollarRate: Double?
        var openedSections = Set<Int>()

        var sections: [Section] {
            if let functionCallMetaData = functionCallMetaData {
                return [.balance, .gas, .amount, .network, .recipient, .function(functionCallMetaData)]
            } else {
                return [.balance, .gas, .amount, .network, .recipient]
            }
        }

        var placeholderIcon: UIImage? {
            return requester == nil ? R.image.awLogoSmall() : R.image.walletConnectIcon()
        }
        let transactionType: TransactionType
        var dappIconUrl: URL? { requester?.iconUrl }
        var ensName: String? { recipientResolver.ensName }
        var addressString: String? { recipientResolver.address?.eip55String }

        init(configurator: TransactionConfigurator, assetDefinitionStore: AssetDefinitionStore, recipientResolver: RecipientResolver, requester: RequesterViewModel?) {
            self.recipientResolver = recipientResolver
            self.assetDefinitionStore = assetDefinitionStore
            self.configurator = configurator
            self.functionCallMetaData = configurator.transaction.data.flatMap { DecodedFunctionCall(data: $0) }
            self.session = configurator.session
            self.requester = requester
            self.transactionType = configurator.transaction.transactionType
        }

        func updateBalance(_ balanceViewModel: BalanceViewModel?) {
            if let viewModel = balanceViewModel {
                let token = transactionType.tokenObject
                switch token.type {
                case .nativeCryptocurrency:
                    balance = "\(viewModel.amountShort) \(viewModel.symbol)"
                    let newAmountShort = EtherNumberFormatter.short.string(from: abs(viewModel.value - configurator.transaction.value))
                    newBalance = R.string.localizable.transactionConfirmationSendSectionBalanceNewTitle(newAmountShort, viewModel.symbol)
                case .erc1155, .erc20, .erc721, .erc721ForTickets, .erc875:
                    let symbol = token.symbolInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
                    let newAmountShort = EtherNumberFormatter.short.string(from: abs(viewModel.value - configurator.transaction.value), decimals: token.decimals)
                    balance = "\(viewModel.amountShort) \(symbol)"
                    newBalance = R.string.localizable.transactionConfirmationSendSectionBalanceNewTitle(newAmountShort, symbol)
                }
            } else {
                balance = .none
                newBalance = .none
            }
        }

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            func shouldHideChevron(for section: Int) -> Bool {
                switch sections[section] {
                case .recipient: return false
                default: return true
                }
            }

            let configuration: TransactionConfirmationHeaderView.Configuration = .init(
                isOpened: openedSections.contains(section),
                section: section,
                shouldHideChevron: shouldHideChevron(for: section))

            let headerName = sections[section].title
            switch sections[section] {
            case .balance:
                let title = R.string.localizable.tokenTransactionConfirmationDefault()
                return .init(title: .normal(balance ?? title), headerName: headerName, details: newBalance, configuration: configuration)
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, configuration: configuration)
            case .gas:
                let gasFee = gasFeeString(for: configurator, cryptoToDollarRate: cryptoToDollarRate)
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, details: gasFee, configuration: configuration)
                } else {
                    return .init(title: .normal(configurationTitle), headerName: headerName, details: gasFee, configuration: configuration)
                }
            case .amount:
                return .init(title: .normal(formattedAmountValue), headerName: headerName, configuration: configuration)
            case .function(let functionCallMetaData):
                return .init(title: .normal(functionCallMetaData.name), headerName: headerName, configuration: configuration)
            case .recipient:
                return .init(title: .normal(recipientResolver.value), headerName: headerName, configuration: configuration)
            }
        }

        func isSubviewsHidden(section: Int, row: Int) -> Bool {
            let isOpened = openedSections.contains(section)
            switch sections[section] {
            case .balance, .gas, .amount, .network, .function:
                return isOpened
            case .recipient:
                if isOpened {
                    switch RecipientResolver.Row.allCases[row] {
                    case .address:
                        return false
                    case .ens:
                        return !recipientResolver.hasResolvedEnsName
                    }
                } else {
                    return true
                }
            }
        }
    }
}
