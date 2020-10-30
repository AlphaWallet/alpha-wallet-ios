// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt

enum TransactionConfirmationViewModel {
    case dappTransaction(DappTransactionViewModel)
    case tokenScriptTransaction(TokenScriptTransactionViewModel)
    case sendFungiblesTransaction(SendFungiblesTransactionViewModel)
    case sendNftTransaction(SendNftTransactionViewModel)

    init(configurator: TransactionConfigurator, configuration: TransactionConfirmationConfiguration) {
        switch configuration {
        case .tokenScriptTransaction(_, let contract, _):
            self = .tokenScriptTransaction(.init(address: contract))
        case .dappTransaction:
            self = .dappTransaction(.init(configurator: configurator))
        case .sendFungiblesTransaction(_, _, let assetDefinitionStore, let amount, let ethPrice):
            let resolver = RecipientResolver(address: configurator.transaction.recipient)
            self = .sendFungiblesTransaction(.init(configurator: configurator, assetDefinitionStore: assetDefinitionStore, recipientResolver: resolver, amount: amount, ethPrice: ethPrice))
        case .sendNftTransaction:
            let resolver = RecipientResolver(address: configurator.transaction.recipient)
            self = .sendNftTransaction(.init(configurator: configurator, recipientResolver: resolver))
        }
    }

    enum Action {
        case show
        case hide
    }

    mutating func showHideSection(_ section: Int) -> Action {
        switch self {
        case .dappTransaction(var viewModel):
            return viewModel.showHideSection(section)
        case .tokenScriptTransaction(var viewModel):
            return viewModel.showHideSection(section)
        case .sendFungiblesTransaction(var viewModel):
            return viewModel.showHideSection(section)
        case .sendNftTransaction(var viewModel):
            return viewModel.showHideSection(section)
        }
    }
}

protocol SectionProtocol {
    var openedSections: Set<Int> { get set }

    mutating func showHideSection(_ section: Int) -> TransactionConfirmationViewModel.Action
}

extension SectionProtocol {
    mutating func showHideSection(_ section: Int) -> TransactionConfirmationViewModel.Action {
        if !openedSections.contains(section) {
            openedSections.insert(section)

            return .show
        } else {
            openedSections.remove(section)

            return .hide
        }
    }
}

enum UpdateBalanceValue {
    case nativeCryptocurrency(balanceViewModel: BalanceBaseViewModel?)
    case erc20(token: TokenObject)
    case other
}

extension TransactionConfirmationViewModel {
    class SendFungiblesTransactionViewModel: SectionProtocol {
        enum Section: Int, CaseIterable {
            case balance
            case gas
            case recipient
            case amount

            var title: String {
                switch self {
                case .gas:
                    return R.string.localizable.transactionConfirmationSendSectionGasTitle()
                case .balance:
                    return R.string.localizable.transactionConfirmationSendSectionBalanceTitle()
                case .amount:
                    return R.string.localizable.transactionConfirmationSendSectionAmountTitle()
                case .recipient:
                    return R.string.localizable.transactionConfirmationSendSectionRecipientTitle()
                }
            }
        }

        private let amount: String
        private var balance: String?
        private var newBalance: String?
        private let configurator: TransactionConfigurator
        private let assetDefinitionStore: AssetDefinitionStore
        private var defaultTitle: String {
            R.string.localizable.tokenTransactionConfirmationDefault()
        }
        private var configurationTitle: String {
            configurator.selectedConfigurationType.title
        }

        var cryptoToDollarRate: Double?
        var ensName: String? { recipientResolver.ensName }
        var addressString: String? { recipientResolver.address?.eip55String }
        var openedSections = Set<Int>()
        let transferType: TransferType
        let session: WalletSession
        let recipientResolver: RecipientResolver
        let ethPrice: Subscribable<Double>

        var sections: [Section] {
            Section.allCases
        }

        init(configurator: TransactionConfigurator, assetDefinitionStore: AssetDefinitionStore, recipientResolver: RecipientResolver, amount: String, ethPrice: Subscribable<Double>) {
            self.configurator = configurator
            self.transferType = configurator.transaction.transferType
            self.session = configurator.session
            self.assetDefinitionStore = assetDefinitionStore
            self.recipientResolver = recipientResolver
            self.amount = amount
            self.ethPrice = ethPrice
        }

        func updateBalance(_ value: UpdateBalanceValue) {
            switch value {
            case .nativeCryptocurrency(let balanceViewModel):
                guard let viewModel = balanceViewModel else { return }
                balance = "\(viewModel.amountShort) \(viewModel.symbol)"
                if let balance = session.balanceCoordinator.balance?.value {
                    let newAmountShort = EtherNumberFormatter.short.string(from: balance - configurator.transaction.value)
                    newBalance = R.string.localizable.transactionConfirmationSendSectionBalanceNewTitle(newAmountShort, viewModel.symbol)
                }
            case .erc20(let token):
                let amount = EtherNumberFormatter.short.string(from: token.valueBigInt, decimals: token.decimals)
                let symbol = token.symbolInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
                let newAmountShort = EtherNumberFormatter.short.string(from: token.valueBigInt - configurator.transaction.value, decimals: token.decimals)
                balance = "\(amount) \(symbol)"
                newBalance = R.string.localizable.transactionConfirmationSendSectionBalanceNewTitle(newAmountShort, symbol)
            case .other:
                break
            }
        }

        var formattedAmountValue: String {
            switch transferType {
            case .nativeCryptocurrency(let token, _, _):
                let cryptoToDollarSymbol = Constants.Currency.usd
                if let cryptoToDollarRate = cryptoToDollarRate, let amount = Double(amount) {
                    let cryptoToDollarValue = StringFormatter().currency(with: amount * cryptoToDollarRate, and: cryptoToDollarSymbol)
                    return "\(amount) \(token.symbol) ≈ \(cryptoToDollarValue) \(cryptoToDollarSymbol)"
                } else {
                    return "\(amount) \(token.symbol)"
                }
            case .ERC20Token(let token, _, _):
                return "\(amount) \(token.symbol)"
            case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp, .tokenScript:
                return String()
            }
        }

        func isSubviewsHidden(section: Int, row: Int) -> Bool {
            let isOpened = openedSections.contains(section)

            switch sections[section] {
            case .balance, .amount, .gas:
                return isOpened
            case .recipient:
                if isOpened {
                    switch RecipientResolver.Row.allCases[row] {
                    case .address:
                        return false
                    case .ens:
                        return recipientResolver.ensName == nil
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
                shouldHideChevron: sections[section] != .recipient
            )

            let placeholder = sections[section].title
            switch sections[section] {
            case .balance:
                let title = R.string.localizable.tokenTransactionConfirmationDefault()
                return .init(title: balance ?? title, placeholder: placeholder, details: newBalance, configuration: configuration)
            case .gas:
                return .init(title: configurationTitle, placeholder: placeholder, configuration: configuration)
            case .amount:
                return .init(title: formattedAmountValue, placeholder: placeholder, configuration: configuration)
            case .recipient:
                return .init(title: recipientResolver.value, placeholder: placeholder, configuration: configuration)
            }
        }
    }

    class DappTransactionViewModel: SectionProtocol {
        enum Section: Int, CaseIterable {
            case gas

            var title: String {
                switch self {
                case .gas:
                    return R.string.localizable.transactionConfirmationSendSectionGasTitle()
                }
            }
        }
        private let configurator: TransactionConfigurator
        private var defaultTitle: String {
            return R.string.localizable.tokenTransactionConfirmationDefault()
        }
        private var configurationTitle: String {
            return configurator.selectedConfigurationType.title
        }

        var openedSections = Set<Int>()

        var sections: [Section] {
            return Section.allCases
        }

        init(configurator: TransactionConfigurator) {
            self.configurator = configurator
        }

        func isSubviewHidden(section: Int, row: Int) -> Bool {
            let _ = openedSections.contains(section)
            switch sections[section] {
            case .gas:
                return true
            }
        }

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let configuration: TransactionConfirmationHeaderView.Configuration = .init(
                isOpened: openedSections.contains(section),
                section: section,
                shouldHideChevron: true
            )

            let placeholder = sections[section].title
            switch sections[section] {
            case .gas:
                return .init(title: configurationTitle, placeholder: placeholder, configuration: configuration)
            }
        }
    }

    class TokenScriptTransactionViewModel: SectionProtocol {
        enum Section: Int, CaseIterable {
            case gas
            case contract

            var title: String {
                switch self {
                case .gas:
                    return R.string.localizable.tokenTransactionConfirmationGasTitle()
                case .contract:
                    return R.string.localizable.tokenTransactionConfirmationContractTitle()
                }
            }
        }

        private let address: AlphaWallet.Address
        private var defaultTitle: String {
            return R.string.localizable.tokenTransactionConfirmationDefault()
        }

        var openedSections = Set<Int>()
        var sections: [Section] {
            return Section.allCases
        }

        init(address: AlphaWallet.Address) {
            self.address = address
        }

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let configuration = TransactionConfirmationHeaderView.Configuration(isOpened: openedSections.contains(section), section: section)

            let placeholder = sections[section].title
            switch sections[section] {
            case .gas:
                return .init(title: defaultTitle, placeholder: placeholder, configuration: configuration)
            case .contract:
                return .init(title: address.truncateMiddle, placeholder: placeholder, configuration: configuration)
            }
        }
    }

    class SendNftTransactionViewModel: SectionProtocol {
        enum Section: Int, CaseIterable {
            case gas
            case recipient
            case tokenId

            var title: String {
                switch self {
                case .gas:
                    return R.string.localizable.transactionConfirmationSendSectionGasTitle()
                case .recipient:
                    return R.string.localizable.transactionConfirmationSendSectionRecipientTitle()
                case .tokenId:
                    return R.string.localizable.transactionConfirmationSendSectionTokenIdTitle()
                }
            }
        }

        private let configurator: TransactionConfigurator
        private let transferType: TransferType
        private let session: WalletSession

        private var configurationTitle: String {
            configurator.selectedConfigurationType.title
        }

        private var defaultTitle: String {
            R.string.localizable.tokenTransactionConfirmationDefault()
        }

        var ensName: String? { recipientResolver.ensName }
        var addressString: String? { recipientResolver.address?.eip55String }
        var openedSections = Set<Int>()
        let recipientResolver: RecipientResolver
        var sections: [Section] {
            return Section.allCases
        }

        init(configurator: TransactionConfigurator, recipientResolver: RecipientResolver) {
            self.configurator = configurator
            self.transferType = configurator.transaction.transferType
            self.session = configurator.session
            self.recipientResolver = recipientResolver
        }

        func isSubviewsHidden(section: Int, row: Int) -> Bool {
            let isOpened = openedSections.contains(section)
            switch sections[section] {
            case .gas, .tokenId:
                return isOpened
            case .recipient:
                if isOpened {
                    switch RecipientResolver.Row.allCases[row] {
                    case .address:
                        return false
                    case .ens:
                        return recipientResolver.ensName == nil
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
                    shouldHideChevron: sections[section] != .recipient
            )

            let placeholder = sections[section].title
            switch sections[section] {
            case .gas:
                return .init(title: configurationTitle, placeholder: placeholder, configuration: configuration)
            case .tokenId:
                //TODO be good to display the token instance's name or equivalent too
                let tokenId = configurator.transaction.tokenId.flatMap({ String($0) }) ?? ""
                return .init(title: tokenId, placeholder: placeholder, configuration: configuration)
            case .recipient:
                return .init(title: recipientResolver.value, placeholder: placeholder, configuration: configuration)
            }
        }
    }
}

extension TransactionConfirmationViewModel {
    var navigationTitle: String {
        switch self {
        case .sendFungiblesTransaction, .sendNftTransaction:
            return R.string.localizable.tokenTransactionTransferConfirmationTitle()
        case .dappTransaction, .tokenScriptTransaction:
            return R.string.localizable.tokenTransactionConfirmationTitle()
        }
    }

    var title: String {
        return R.string.localizable.confirmPaymentConfirmButtonTitle()
    }
    var confirmationButtonTitle: String {
        return R.string.localizable.confirmPaymentConfirmButtonTitle()
    }

    var backgroundColor: UIColor {
        return UIColor.clear
    }

    var footerBackgroundColor: UIColor {
        return R.color.white()!
    }
}
