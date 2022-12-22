//
//  SendFungiblesTransactionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2022.
//

import UIKit
import BigInt
import AlphaWalletFoundation

extension TransactionConfirmationViewModel {
    class SendFungiblesTransactionViewModel: ExpandableSection, RateUpdatable {
        enum Section: Int, CaseIterable {
            case balance
            case network
            case gas
            case recipient
            case amount

            var title: String {
                switch self {
                case .network:
                    return R.string.localizable.tokenTransactionConfirmationNetwork()
                case .gas:
                    return R.string.localizable.tokenTransactionConfirmationGasTitle()
                case .balance:
                    return R.string.localizable.transactionConfirmationSendSectionBalanceTitle()
                case .amount:
                    return R.string.localizable.transactionConfirmationSendSectionAmountTitle()
                case .recipient:
                    return R.string.localizable.transactionConfirmationSendSectionRecipientTitle()
                }
            }
        }

        private var balance: Double = .zero
        private var newBalance: Double = .zero
        private let configurator: TransactionConfigurator
        private let assetDefinitionStore: AssetDefinitionStore
        private var configurationTitle: String {
            configurator.selectedConfigurationType.title
        }
        private let recipientResolver: RecipientResolver

        var rate: CurrencyRate?
        var ensName: String? { recipientResolver.ensName }
        var addressString: String? { recipientResolver.address?.eip55String }
        var openedSections = Set<Int>()
        let transactionType: TransactionType
        let session: WalletSession

        var sections: [Section] {
            Section.allCases
        }

        init(configurator: TransactionConfigurator, assetDefinitionStore: AssetDefinitionStore, recipientResolver: RecipientResolver) {
            self.configurator = configurator
            self.transactionType = configurator.transaction.transactionType
            self.session = configurator.session
            self.assetDefinitionStore = assetDefinitionStore
            self.recipientResolver = recipientResolver
        }

        func updateBalance(_ balanceViewModel: BalanceViewModel?) {
            if let balanceViewModel = balanceViewModel {
                let token = transactionType.tokenObject
                switch token.type {
                case .nativeCryptocurrency:
                    balance = balanceViewModel.valueDecimal.doubleValue

                    var amountToSend: Double
                    switch configurator.transaction.transactionType.amount {
                    case .notSet, .none:
                        amountToSend = .zero
                    case .amount(let value):
                        amountToSend = value
                    case .allFunds:
                        //NOTE: ignore passed value of 'allFunds', as we recalculating it again
                        configurator.updateTransaction(value: BigUInt(balanceViewModel.value) - configurator.gasValue)
                        amountToSend = balance
                    }

                    newBalance = abs(balance - amountToSend)
                case .erc20:
                    balance = balanceViewModel.valueDecimal.doubleValue

                    let amountToSend: Double
                    switch transactionType.amount {
                    case .notSet, .none:
                        amountToSend = .zero
                    case .amount(let value):
                        amountToSend = value
                    case .allFunds:
                        amountToSend = balance
                    }

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

        private var formattedAmountValue: String {
            //NOTE: when we send .allFunds for native crypto its going to be overriden with .allFunds(value - gas)
            let amountToSend: Double

            //NOTE: special case for `nativeCryptocurrency` we amount - gas displayd in `amount` section
            switch transactionType {
            case .nativeCryptocurrency(let token, _, _):
                switch transactionType.amount {
                case .amount(let value):
                    amountToSend = value
                case .allFunds:
                    //NOTE: special case for `nativeCryptocurrency` we amount - gas displayd in `amount` section
                    amountToSend = abs(balance - (Decimal(bigUInt: configurator.gasValue, decimals: token.decimals) ?? .zero).doubleValue)
                case .notSet, .none:
                    amountToSend = .zero
                }
            case .erc20Token:
                switch transactionType.amount {
                case .amount(let value):
                    amountToSend = value
                case .allFunds:
                    amountToSend = balance
                case .notSet, .none:
                    amountToSend = .zero
                }
            case .prebuilt:
                amountToSend = (Decimal(bigUInt: configurator.transaction.value, decimals: session.server.decimals) ?? .zero).doubleValue
            case .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token:
                amountToSend = .zero
            }

            switch transactionType {
            case .nativeCryptocurrency, .erc20Token, .prebuilt:
                let symbol: String
                switch transactionType.tokenObject.type {
                case .nativeCryptocurrency:
                    symbol = transactionType.tokenObject.symbol
                case .erc20, .erc1155, .erc721, .erc721ForTickets, .erc875:
                    symbol = transactionType.tokenObject.symbolInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
                }

                //TODO: extract to constants
                let amount = NumberFormatter.shortCrypto.string(double: amountToSend, minimumFractionDigits: 4, maximumFractionDigits: 8)
                if let rate = rate {
                    let amountInFiat = NumberFormatter.fiat(currency: rate.currency).string(double: amountToSend * rate.value, minimumFractionDigits: 2, maximumFractionDigits: 6)
                    
                    return "\(amount) \(symbol) ≈ \(amountInFiat)"
                } else {
                    return "\(amount) \(symbol)"
                }
            case .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token:
                return String()
            }
        }

        func isSubviewsHidden(section: Int, row: Int) -> Bool {
            let isOpened = openedSections.contains(section)

            switch sections[section] {
            case .balance, .amount, .gas, .network:
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

        private var formattedNewBalanceString: String {
            let symbol: String
            switch transactionType.tokenObject.type {
            case .nativeCryptocurrency:
                symbol = transactionType.tokenObject.symbol
            case .erc20, .erc1155, .erc721, .erc721ForTickets, .erc875:
                symbol = transactionType.tokenObject.symbolInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
            }
            let newBalance = NumberFormatter.shortCrypto.string(for: newBalance) ?? "-"

            return R.string.localizable.transactionConfirmationSendSectionBalanceNewTitle("\(newBalance) \(symbol)", symbol)
        }

        private var formattedBalanceString: String {
            let title = R.string.localizable.tokenTransactionConfirmationDefault()
            let symbol: String
            switch transactionType.tokenObject.type {
            case .nativeCryptocurrency:
                symbol = transactionType.tokenObject.symbol
            case .erc20, .erc1155, .erc721, .erc721ForTickets, .erc875:
                symbol = transactionType.tokenObject.symbolInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
            }

            let balance = NumberFormatter.alternateAmount.string(double: balance)


            return balance.flatMap { "\($0) \(symbol)" } ?? title
        }

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let configuration: TransactionConfirmationHeaderView.Configuration = .init(
                isOpened: openedSections.contains(section),
                section: section,
                shouldHideChevron: sections[section] != .recipient)

            let headerName = sections[section].title

            switch sections[section] {
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, configuration: configuration)
            case .balance:
                return .init(title: .normal(formattedBalanceString), headerName: headerName, details: formattedNewBalanceString, configuration: configuration)
            case .gas:
                let gasFee = gasFeeString(for: configurator, rate: rate)
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, details: gasFee, configuration: configuration)
                } else {
                    return .init(title: .normal(configurationTitle), headerName: headerName, details: gasFee, configuration: configuration)
                }
            case .amount:
                return .init(title: .normal(formattedAmountValue), headerName: headerName, configuration: configuration)
            case .recipient:
                return .init(title: .normal(recipientResolver.value), headerName: headerName, configuration: configuration)
            }
        }
    }
}
