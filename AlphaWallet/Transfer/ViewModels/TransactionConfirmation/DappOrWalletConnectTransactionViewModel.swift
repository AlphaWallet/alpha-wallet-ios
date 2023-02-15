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
    //TODO: pretty all of `TransactionViewModels` have balance, newBalance and so on, maybe move to base class or protocol definition
    class DappOrWalletConnectTransactionViewModel: ExpandableSection, RateUpdatable, BalanceUpdatable {
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

        private var balance: Double = .zero
        private var newBalance: Double = .zero

        private let configurator: TransactionConfigurator
        private var configurationTitle: String {
            return configurator.selectedConfigurationType.title
        }
        private var requester: RequesterViewModel?
        private let assetDefinitionStore: AssetDefinitionStore
        private var formattedAmountValue: String {
            let amountToSend = (Decimal(bigUInt: configurator.transaction.value, decimals: configurator.session.server.decimals) ?? .zero).doubleValue
            //NOTE: previously it was full, make it full
            let amount = NumberFormatter.shortCrypto.string(double: amountToSend) ?? "-"

            if let rate = rate {
                let amountInFiat = NumberFormatter.fiat(currency: rate.currency).string(double: amountToSend * rate.value) ?? "-"
                return "\(amount) \(configurator.session.server.symbol) ≈ \(amountInFiat)"
            } else {
                return "\(amount) \(configurator.session.server.symbol)"
            }
        }
        private let recipientResolver: RecipientResolver
        let session: WalletSession
        let functionCallMetaData: DecodedFunctionCall?
        var rate: CurrencyRate?
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
        private let transactionType: TransactionType
        var dappIconUrl: URL? { requester?.iconUrl }
        var ensName: String? { recipientResolver.ensName }
        var addressString: String? { recipientResolver.address?.eip55String }

        init(configurator: TransactionConfigurator, assetDefinitionStore: AssetDefinitionStore, recipientResolver: RecipientResolver, requester: RequesterViewModel?) {
            self.recipientResolver = recipientResolver
            self.assetDefinitionStore = assetDefinitionStore
            self.configurator = configurator
            self.functionCallMetaData = DecodedFunctionCall(data: configurator.transaction.data)
            self.session = configurator.session
            self.requester = requester
            self.transactionType = configurator.transaction.transactionType
        }

        func updateBalance(_ balanceViewModel: BalanceViewModel?) {
            if let viewModel = balanceViewModel {
                let token = transactionType.tokenObject
                switch token.type {
                case .nativeCryptocurrency, .erc20:
                    balance = viewModel.valueDecimal.doubleValue
                    let amountToSend = (Decimal(bigUInt: configurator.transaction.value, decimals: token.decimals) ?? .zero).doubleValue
                    newBalance = abs(balance - amountToSend)
                case .erc1155, .erc721, .erc721ForTickets, .erc875:
                    balance = .zero
                    newBalance = .zero
                }
            } else {
                balance = .zero
                newBalance = .zero
            }
        }

        private var formattedNewBalanceString: String {
            let symbol: String
            switch transactionType.tokenObject.type {
            case .nativeCryptocurrency:
                symbol = transactionType.tokenObject.symbol
            case .erc20, .erc1155, .erc721, .erc721ForTickets, .erc875:
                symbol = session.tokenAdaptor.tokenScriptOverrides(token: transactionType.tokenObject).symbolInPluralForm
            }
            let newBalance = NumberFormatter.shortCrypto.string(for: newBalance) ?? "-"

            return R.string.localizable.transactionConfirmationSendSectionBalanceNewTitle("\(newBalance) \(symbol)", "symbol")
        }

        private var formattedBalanceString: String {
            let title = R.string.localizable.tokenTransactionConfirmationDefault()
            let symbol: String
            switch transactionType.tokenObject.type {
            case .nativeCryptocurrency:
                symbol = transactionType.tokenObject.symbol
            case .erc20, .erc1155, .erc721, .erc721ForTickets, .erc875:
                symbol = session.tokenAdaptor.tokenScriptOverrides(token: transactionType.tokenObject).symbolInPluralForm
            }

            let balance = NumberFormatter.shortCrypto.string(for: balance)

            return balance.flatMap { "\($0) \(symbol)" } ?? title
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
                return .init(title: .normal(formattedBalanceString), headerName: headerName, details: formattedNewBalanceString, configuration: configuration)
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, configuration: configuration)
            case .gas:
                let gasFee = gasFeeString(for: configurator, rate: rate)
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
