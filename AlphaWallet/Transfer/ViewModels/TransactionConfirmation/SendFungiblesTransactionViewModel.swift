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
    class SendFungiblesTransactionViewModel: SectionProtocol, CryptoToFiatRateUpdatable {
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

        private var amount: FungiblesTransactionAmount
        private var balance: String?
        private var newBalance: String?
        private let configurator: TransactionConfigurator
        private let assetDefinitionStore: AssetDefinitionStore
        private var configurationTitle: String {
            configurator.selectedConfigurationType.title
        }
        private let recipientResolver: RecipientResolver

        var cryptoToDollarRate: Double?
        var ensName: String? { recipientResolver.ensName }
        var addressString: String? { recipientResolver.address?.eip55String }
        var openedSections = Set<Int>()
        let transactionType: TransactionType
        let session: WalletSession

        var sections: [Section] {
            Section.allCases
        }

        init(configurator: TransactionConfigurator, assetDefinitionStore: AssetDefinitionStore, recipientResolver: RecipientResolver, amount: FungiblesTransactionAmount) {
            self.configurator = configurator
            self.transactionType = configurator.transaction.transactionType
            self.session = configurator.session
            self.assetDefinitionStore = assetDefinitionStore
            self.recipientResolver = recipientResolver
            self.amount = amount
        }

        func updateBalance(_ balanceViewModel: BalanceViewModel?) {
            if let viewModel = balanceViewModel {
                let token = transactionType.tokenObject
                switch token.type {
                case .nativeCryptocurrency:
                    balance = "\(viewModel.amountShort) \(viewModel.symbol)"

                    var availableAmount: BigInt
                    if amount.isAllFunds {
                        //NOTE: we need to handle balance updates, and refresh `amount` balance - gas
                        //if balance is equals to 0, or in case when value (balance - gas) less then zero we willn't crash
                        let allFundsWithoutGas = abs(viewModel.value - configurator.gasValue)
                        availableAmount = allFundsWithoutGas

                        configurator.updateTransaction(value: allFundsWithoutGas)
                        amount.value = EtherNumberFormatter.short.string(from: allFundsWithoutGas, units: .ether)
                    } else {
                        availableAmount = viewModel.value
                    }

                    let newAmountShort = EtherNumberFormatter.short.string(from: abs(availableAmount - configurator.transaction.value))
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

        var formattedAmountValue: String {
            switch transactionType {
            case .nativeCryptocurrency(let token, _, _):
                if let cryptoToDollarRate = cryptoToDollarRate {
                    let cryptoToDollarSymbol = Constants.Currency.usd
                    let double = amount.value.optionalDecimalValue ?? 0
                    let value = double.multiplying(by: NSDecimalNumber(value: cryptoToDollarRate))
                    let cryptoToDollarValue = StringFormatter().currency(with: value, and: cryptoToDollarSymbol)

                    return "\(amount.value) \(token.symbol) ≈ \(cryptoToDollarValue) \(cryptoToDollarSymbol)"
                } else {
                    return "\(amount.value) \(token.symbol)"
                }
            case .erc20Token(let token, _, _):
                if let amount = amount.shortValue, amount.nonEmpty {
                    return "\(amount) \(token.symbol)"
                } else {
                    return "\(amount.value) \(token.symbol)"
                }
            case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
                return String()
            }
        }

        var gasFee: String {
            let fee: BigInt = configurator.currentConfiguration.gasPrice * configurator.currentConfiguration.gasLimit
            let feeString = EtherNumberFormatter.short.string(from: fee)
            let cryptoToDollarSymbol = Constants.Currency.usd
            if let cryptoToDollarRate = cryptoToDollarRate {
                let cryptoToDollarValue = StringFormatter().currency(with: Double(fee) * cryptoToDollarRate / Double(EthereumUnit.ether.rawValue), and: cryptoToDollarSymbol)
                return "< ~\(feeString) \(session.server.symbol) (\(cryptoToDollarValue) \(cryptoToDollarSymbol))"
            } else {
                return "< ~\(feeString) \(session.server.symbol)"
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
                let title = R.string.localizable.tokenTransactionConfirmationDefault()
                return .init(title: .normal(balance ?? title), headerName: headerName, details: newBalance, configuration: configuration)
            case .gas:
                let gasFee = gasFeeString(for: configurator, cryptoToDollarRate: cryptoToDollarRate)
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
