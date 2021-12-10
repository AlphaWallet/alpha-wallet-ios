// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt

enum TransactionConfirmationViewModel {
    case dappOrWalletConnectTransaction(DappOrWalletConnectTransactionViewModel)
    case tokenScriptTransaction(TokenScriptTransactionViewModel)
    case sendFungiblesTransaction(SendFungiblesTransactionViewModel)
    case sendNftTransaction(SendNftTransactionViewModel)
    case claimPaidErc875MagicLink(ClaimPaidErc875MagicLinkViewModel)
    case speedupTransaction(SpeedupTransactionViewModel)
    case cancelTransaction(CancelTransactionViewModel)

    init(configurator: TransactionConfigurator, configuration: TransactionConfirmationConfiguration) {
        switch configuration {
        case .tokenScriptTransaction(_, let contract, _, let functionCallMetaData, let ethPrice):
            self = .tokenScriptTransaction(.init(address: contract, configurator: configurator, functionCallMetaData: functionCallMetaData, ethPrice: ethPrice))
        case .dappTransaction(_, _, let ethPrice):
            self = .dappOrWalletConnectTransaction(.init(configurator: configurator, ethPrice: ethPrice, walletConnectSession: nil))
        case .walletConnect(_, _, let ethPrice, let walletConnectSession):
            self = .dappOrWalletConnectTransaction(.init(configurator: configurator, ethPrice: ethPrice, walletConnectSession: walletConnectSession))
        case .sendFungiblesTransaction(_, _, let assetDefinitionStore, let amount, let ethPrice):
            let resolver = RecipientResolver(address: configurator.transaction.recipient)
            self = .sendFungiblesTransaction(.init(configurator: configurator, assetDefinitionStore: assetDefinitionStore, recipientResolver: resolver, amount: amount, ethPrice: ethPrice))
        case .sendNftTransaction(_, _, let ethPrice, let tokenInstanceNames):
            let resolver = RecipientResolver(address: configurator.transaction.recipient)
            self = .sendNftTransaction(.init(configurator: configurator, recipientResolver: resolver, ethPrice: ethPrice, tokenInstanceNames: tokenInstanceNames))
        case .claimPaidErc875MagicLink(_, _, let price, let ethPrice, let numberOfTokens):
            self = .claimPaidErc875MagicLink(.init(configurator: configurator, price: price, ethPrice: ethPrice, numberOfTokens: numberOfTokens))
        case .speedupTransaction(_, let ethPrice):
            self = .speedupTransaction(.init(configurator: configurator, ethPrice: ethPrice))
        case .cancelTransaction(_, let ethPrice):
            self = .cancelTransaction(.init(configurator: configurator, ethPrice: ethPrice))
        }
    }

    enum Action {
        case show
        case hide
    }

    mutating func showHideSection(_ section: Int) -> Action {
        switch self {
        case .dappOrWalletConnectTransaction(var viewModel):
            return viewModel.showHideSection(section)
        case .tokenScriptTransaction(var viewModel):
            return viewModel.showHideSection(section)
        case .sendFungiblesTransaction(var viewModel):
            return viewModel.showHideSection(section)
        case .sendNftTransaction(var viewModel):
            return viewModel.showHideSection(section)
        case .claimPaidErc875MagicLink(var viewModel):
            return viewModel.showHideSection(section)
        case .speedupTransaction(var viewModel):
            return viewModel.showHideSection(section)
        case .cancelTransaction(var viewModel):
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
    private static func gasFeeString(withConfigurator configurator: TransactionConfigurator, cryptoToDollarRate: Double?) -> String {
        let fee = configurator.currentConfiguration.gasPrice * configurator.currentConfiguration.gasLimit
        let estimatedProcessingTime = configurator.selectedConfigurationType.estimatedProcessingTime
        let symbol = configurator.session.server.symbol
        let feeString = EtherNumberFormatter.short.string(from: fee)
        let cryptoToDollarSymbol = Constants.Currency.usd
        let costs: String
        if let cryptoToDollarRate = cryptoToDollarRate {
            let cryptoToDollarValue = StringFormatter().currency(with: Double(fee) * cryptoToDollarRate / Double(EthereumUnit.ether.rawValue), and: cryptoToDollarSymbol)
            costs =  "< ~\(feeString) \(symbol) (\(cryptoToDollarValue) \(cryptoToDollarSymbol))"
        } else {
            costs = "< ~\(feeString) \(symbol)"
        }

        if estimatedProcessingTime.isEmpty {
            return costs
        } else {
            return "\(costs) \(estimatedProcessingTime)"
        }
    }

    class SendFungiblesTransactionViewModel: SectionProtocol {
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

        var cryptoToDollarRate: Double?
        var ensName: String? { recipientResolver.ensName }
        var addressString: String? { recipientResolver.address?.eip55String }
        var openedSections = Set<Int>()
        let transactionType: TransactionType
        let session: WalletSession
        let recipientResolver: RecipientResolver
        let ethPrice: Subscribable<Double>

        var server: RPCServer {
            configurator.session.server
        }

        var sections: [Section] {
            Section.allCases
        }

        init(configurator: TransactionConfigurator, assetDefinitionStore: AssetDefinitionStore, recipientResolver: RecipientResolver, amount: FungiblesTransactionAmount, ethPrice: Subscribable<Double>) {
            self.configurator = configurator
            self.transactionType = configurator.transaction.transactionType
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

                var availableAmount: BigInt
                if amount.isAllFunds {
                    //NOTE: we need to handle balance updates, and refresh `amount` balance - gas
                    //if balance is equals to 0, or in case when value (balance - gas) less then zero we willn't crash
                    let allFundsWithoutGas = viewModel.value - configurator.gasValue
                    availableAmount = allFundsWithoutGas

                    configurator.updateTransaction(value: allFundsWithoutGas)
                    amount.value = EtherNumberFormatter.short.string(from: allFundsWithoutGas, units: .ether)
                } else {
                    availableAmount = viewModel.value
                }

                let newAmountShort = EtherNumberFormatter.short.string(from: availableAmount - configurator.transaction.value)
                newBalance = R.string.localizable.transactionConfirmationSendSectionBalanceNewTitle(newAmountShort, viewModel.symbol)

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
            case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink:
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
                        return !recipientResolver.hasResolvedESNName
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
            let headerName = sections[section].title
            switch sections[section] {
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.iconImage, configuration: configuration)
            case .balance:
                let title = R.string.localizable.tokenTransactionConfirmationDefault()
                return .init(title: .normal(balance ?? title), headerName: headerName, details: newBalance, configuration: configuration)
            case .gas:
                let gasFee = gasFeeString(withConfigurator: configurator, cryptoToDollarRate: cryptoToDollarRate)
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

    class DappOrWalletConnectTransactionViewModel: SectionProtocol {
        enum Section {
            case gas
            case network
            case amount
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
                }
            }

            var isExpandable: Bool {
                switch self {
                case .gas, .amount, .network:
                    return false
                case .function:
                    return true
                }
            }
        }
        private let configurator: TransactionConfigurator
        private var configurationTitle: String {
            return configurator.selectedConfigurationType.title
        }
        let session: WalletSession
        private var formattedAmountValue: String {
            let cryptoToDollarSymbol = Constants.Currency.usd
            let amount = Double(configurator.transaction.value) / Double(EthereumUnit.ether.rawValue)
            let amountString = EtherNumberFormatter.short.string(from: configurator.transaction.value)
            let symbol = configurator.session.server.symbol
            if let cryptoToDollarRate = cryptoToDollarRate {
                let cryptoToDollarValue = StringFormatter().currency(with: amount * cryptoToDollarRate, and: cryptoToDollarSymbol)
                return "\(amountString) \(symbol) ≈ \(cryptoToDollarValue) \(cryptoToDollarSymbol)"
            } else {
                return "\(amountString) \(symbol)"
            }
        }

        let ethPrice: Subscribable<Double>
        let functionCallMetaData: DecodedFunctionCall?
        var cryptoToDollarRate: Double?
        var openedSections = Set<Int>()

        var server: RPCServer {
            configurator.session.server
        }

        var sections: [Section] {
            if let functionCallMetaData = functionCallMetaData {
                return [.gas, .amount, .function(functionCallMetaData)]
            } else {
                return [.gas, .amount]
            }
        }

        var placeholderIcon: UIImage? {
            return walletConnectSession == nil ? R.image.awLogoSmall() : R.image.walletConnectIcon()
        }

        var dappIconUrl: URL? { walletConnectSession?.session.dappIconUrl }

        private var walletConnectSession: WalletConnectSessionMappedToServer?

        init(configurator: TransactionConfigurator, ethPrice: Subscribable<Double>, walletConnectSession: WalletConnectSessionMappedToServer?) {
            self.configurator = configurator
            self.ethPrice = ethPrice
            self.functionCallMetaData = configurator.transaction.data.flatMap { DecodedFunctionCall(data: $0) }
            self.session = configurator.session
            self.walletConnectSession = walletConnectSession
        }

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let configuration: TransactionConfirmationHeaderView.Configuration = .init(isOpened: openedSections.contains(section), section: section, shouldHideChevron: !sections[section].isExpandable)
            let headerName = sections[section].title
            switch sections[section] {
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.iconImage, configuration: configuration)
            case .gas:
                let gasFee = gasFeeString(withConfigurator: configurator, cryptoToDollarRate: cryptoToDollarRate)
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, details: gasFee, configuration: configuration)
                } else {
                    return .init(title: .normal(configurationTitle), headerName: headerName, details: gasFee, configuration: configuration)
                }
            case .amount:
                return .init(title: .normal(formattedAmountValue), headerName: headerName, configuration: configuration)
            case .function(let functionCallMetaData):
                return .init(title: .normal(functionCallMetaData.name), headerName: headerName, configuration: configuration)
            }
        }

        func isSubviewsHidden(section: Int) -> Bool {
            !openedSections.contains(section)
        }
    }

    class TokenScriptTransactionViewModel: SectionProtocol {
        enum Section: Int, CaseIterable {
            case gas
            case network
            case contract
            case function
            case amount

            var title: String {
                switch self {
                case .network:
                    return R.string.localizable.tokenTransactionConfirmationNetwork()
                case .gas:
                    return R.string.localizable.tokenTransactionConfirmationGasTitle()
                case .contract:
                    return R.string.localizable.tokenTransactionConfirmationContractTitle()
                case .function:
                    return R.string.localizable.tokenTransactionConfirmationFunctionTitle()
                case .amount:
                    return R.string.localizable.transactionConfirmationSendSectionAmountTitle()
                }
            }
        }

        private let address: AlphaWallet.Address
        private let configurator: TransactionConfigurator
        private var configurationTitle: String {
            configurator.selectedConfigurationType.title
        }
        private var formattedAmountValue: String {
            let cryptoToDollarSymbol = Constants.Currency.usd
            let amount = Double(configurator.transaction.value) / Double(EthereumUnit.ether.rawValue)
            let amountString = EtherNumberFormatter.short.string(from: configurator.transaction.value)
            let symbol = configurator.session.server.symbol
            if let cryptoToDollarRate = cryptoToDollarRate {
                let cryptoToDollarValue = StringFormatter().currency(with: amount * cryptoToDollarRate, and: cryptoToDollarSymbol)
                return "\(amountString) \(symbol) ≈ \(cryptoToDollarValue) \(cryptoToDollarSymbol)"
            } else {
                return "\(amountString) \(symbol)"
            }
        }

        var cryptoToDollarRate: Double?
        let functionCallMetaData: DecodedFunctionCall
        let ethPrice: Subscribable<Double>
        var openedSections = Set<Int>()
        var sections: [Section] {
            return Section.allCases
        }
        var server: RPCServer {
            configurator.session.server
        }
        let session: WalletSession

        init(address: AlphaWallet.Address, configurator: TransactionConfigurator, functionCallMetaData: DecodedFunctionCall, ethPrice: Subscribable<Double>) {
            self.address = address
            self.configurator = configurator
            self.functionCallMetaData = functionCallMetaData
            self.ethPrice = ethPrice
            self.session = configurator.session
        }

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let configuration = TransactionConfirmationHeaderView.Configuration(isOpened: openedSections.contains(section), section: section, shouldHideChevron: sections[section] != .function)
            let headerName = sections[section].title
            switch sections[section] {
            case .gas:
                let gasFee = gasFeeString(withConfigurator: configurator, cryptoToDollarRate: cryptoToDollarRate)
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, details: gasFee, configuration: configuration)
                } else {
                    return .init(title: .normal(configurationTitle), headerName: headerName, details: gasFee, configuration: configuration)
                }
            case .contract:
                return .init(title: .normal(address.truncateMiddle), headerName: headerName, configuration: configuration)
            case .function:
                return .init(title: .normal(functionCallMetaData.name), headerName: headerName, configuration: configuration)
            case .amount:
                return .init(title: .normal(formattedAmountValue), headerName: headerName, configuration: configuration)
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.iconImage, configuration: configuration)
            }
        }

        func isSubviewsHidden(section: Int) -> Bool {
            !openedSections.contains(section)
        }
    }

    class SendNftTransactionViewModel: SectionProtocol {
        enum Section: Int, CaseIterable {
            case gas
            case network
            case recipient
            case tokenId

            var title: String {
                switch self {
                case .network:
                    return R.string.localizable.tokenTransactionConfirmationNetwork()
                case .gas:
                    return R.string.localizable.tokenTransactionConfirmationGasTitle()
                case .recipient:
                    return R.string.localizable.transactionConfirmationSendSectionRecipientTitle()
                case .tokenId:
                    return R.string.localizable.transactionConfirmationSendSectionTokenIdTitle()
                }
            }
        }

        private let configurator: TransactionConfigurator
        private let transactionType: TransactionType
        private let session: WalletSession
        private let tokenInstanceNames: [TokenId: String]

        var server: RPCServer {
            configurator.session.server
        }

        private var configurationTitle: String {
            configurator.selectedConfigurationType.title
        }

        var ensName: String? { recipientResolver.ensName }
        var addressString: String? { recipientResolver.address?.eip55String }
        var openedSections = Set<Int>()
        let recipientResolver: RecipientResolver
        var cryptoToDollarRate: Double?
        let ethPrice: Subscribable<Double>
        var sections: [Section] {
            return Section.allCases
        }

        init(configurator: TransactionConfigurator, recipientResolver: RecipientResolver, ethPrice: Subscribable<Double>, tokenInstanceNames: [TokenId: String]) {
            self.configurator = configurator
            self.transactionType = configurator.transaction.transactionType
            self.session = configurator.session
            self.recipientResolver = recipientResolver
            self.ethPrice = ethPrice
            self.tokenInstanceNames = tokenInstanceNames
        }

        func isSubviewsHidden(section: Int, row: Int) -> Bool {
            let isOpened = openedSections.contains(section)
            switch sections[section] {
            case .gas, .tokenId, .network:
                return isOpened
            case .recipient:
                if isOpened {
                    switch RecipientResolver.Row.allCases[row] {
                    case .address:
                        return false
                    case .ens:
                        return !recipientResolver.hasResolvedESNName
                    }
                } else {
                    return true
                }
            }
        }

        private var tokenIdsAndValues: [UnconfirmedTransaction.TokenIdAndValue] {
            configurator.transaction.tokenIdsAndValues ?? []
        }

        func tokenIdAndValueViewModels() -> [String] {
            return tokenIdsAndValues.map { tokenIdAndValue in

                let tokenId = tokenIdAndValue.tokenId
                let value = tokenIdAndValue.value
                let title: String

                if let tokenInstanceName = tokenInstanceNames[tokenId], !tokenInstanceName.isEmpty {
                    title = "\(value) x \(tokenInstanceName) (\(tokenId))"
                } else {
                    title = "\(value) x \(tokenId)"
                }

                return title
            }
        }

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let configuration: TransactionConfirmationHeaderView.Configuration = .init(
                    isOpened: openedSections.contains(section),
                    section: section,
                    shouldHideChevron: sections[section] != .recipient
            )

            let headerName = sections[section].title
            switch sections[section] {
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.iconImage, configuration: configuration)
            case .gas:
                let gasFee = gasFeeString(withConfigurator: configurator, cryptoToDollarRate: cryptoToDollarRate)
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, details: gasFee, configuration: configuration)
                } else {
                    return .init(title: .normal(configurationTitle), headerName: headerName, details: gasFee, configuration: configuration)
                }
            case .tokenId:
                switch transactionType {
                case .erc1155Token:
                    let viewModels = tokenIdAndValueViewModels()
                    guard viewModels.count == 1 else {
                        return .init(title: .normal(nil), headerName: "Token IDs", configuration: configuration)
                    }

                    return .init(title: .normal(viewModels.first ?? "-"), headerName: headerName, configuration: configuration)
                case .nativeCryptocurrency, .erc20Token, .erc721Token, .claimPaidErc875MagicLink, .erc875Token, .erc875TokenOrder, .erc721ForTicketToken, .dapp, .tokenScript:
                    //This is really just for ERC721, but the type system…
                    let tokenId = configurator.transaction.tokenId.flatMap({ String($0) })
                    let title: String
                    let tokenInstanceName = configurator.transaction.tokenId.flatMap { tokenInstanceNames[$0] }

                    if let tokenInstanceName = tokenInstanceName, !tokenInstanceName.isEmpty {
                        if let tokenId = tokenId {
                            title = "\(tokenInstanceName) (\(tokenId))"
                        } else {
                            title = tokenInstanceName
                        }
                    } else {
                        title = tokenId ?? ""
                    }
                    return .init(title: .normal(title), headerName: headerName, configuration: configuration)
                }
            case .recipient:
                return .init(title: .normal(recipientResolver.value), headerName: headerName, configuration: configuration)
            }
        }
    }

    class ClaimPaidErc875MagicLinkViewModel: SectionProtocol {
        enum Section: Int, CaseIterable {
            case gas
            case network
            case amount
            case numberOfTokens

            var title: String {
                switch self {
                case .network:
                    return R.string.localizable.tokenTransactionConfirmationNetwork()
                case .gas:
                    return R.string.localizable.tokenTransactionConfirmationGasTitle()
                case .amount:
                    return R.string.localizable.transactionConfirmationSendSectionAmountTitle()
                case .numberOfTokens:
                    return R.string.localizable.tokensTitlecase()
                }
            }
        }
        private let configurator: TransactionConfigurator
        private let price: BigUInt
        private let numberOfTokens: UInt
        let session: WalletSession
        private var defaultTitle: String {
            return R.string.localizable.tokenTransactionConfirmationDefault()
        }
        private var configurationTitle: String {
            return configurator.selectedConfigurationType.title
        }

        var openedSections = Set<Int>()
        let ethPrice: Subscribable<Double>
        var cryptoToDollarRate: Double?

        var server: RPCServer {
            configurator.session.server
        }

        var sections: [Section] {
            return Section.allCases
        }

        init(configurator: TransactionConfigurator, price: BigUInt, ethPrice: Subscribable<Double>, numberOfTokens: UInt) {
            self.configurator = configurator
            self.price = price
            self.ethPrice = ethPrice
            self.numberOfTokens = numberOfTokens
            self.session = configurator.session
        }

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let configuration: TransactionConfirmationHeaderView.Configuration = .init(
                    isOpened: openedSections.contains(section),
                    section: section,
                    shouldHideChevron: true
            )

            let headerName = sections[section].title
            switch sections[section] {
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.iconImage, configuration: configuration)
            case .gas:
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, configuration: configuration)
                } else {
                    return .init(title: .normal(configurationTitle), headerName: headerName, configuration: configuration)
                }
            case .amount:
                let cryptoToDollarSymbol = Constants.Currency.usd
                let nativeCryptoSymbol = configurator.session.server.symbol
                let formattedAmountValue: String
                let nativeCryptoPrice = EtherNumberFormatter.short.string(from: BigInt(price))
                if let cryptoToDollarRate = cryptoToDollarRate {
                    let cryptoToDollarValue = StringFormatter().currency(with: Double(price) * cryptoToDollarRate / Double(EthereumUnit.ether.rawValue), and: cryptoToDollarSymbol)
                    formattedAmountValue = "\(nativeCryptoPrice) \(nativeCryptoSymbol) ≈ \(cryptoToDollarValue) \(cryptoToDollarSymbol)"
                } else {
                    formattedAmountValue = "\(nativeCryptoPrice) \(nativeCryptoSymbol)"
                }
                return .init(title: .normal(formattedAmountValue), headerName: headerName, configuration: configuration)
            case .numberOfTokens:
                return .init(title: .normal(String(numberOfTokens)), headerName: headerName, configuration: configuration)
            }
        }
    }

    class SpeedupTransactionViewModel: SectionProtocol {
        enum Section {
            case gas
            case description

            var title: String {
                switch self {
                case .gas:
                    return R.string.localizable.tokenTransactionConfirmationGasTitle()
                case .description:
                    return R.string.localizable.activitySpeedupDescription()
                }
            }

            var isExpandable: Bool {
                switch self {
                case .gas, .description:
                    return false
                }
            }
        }
        private let configurator: TransactionConfigurator
        private var configurationTitle: String {
            return configurator.selectedConfigurationType.title
        }
        let session: WalletSession
        let ethPrice: Subscribable<Double>
        var cryptoToDollarRate: Double?
        var openedSections = Set<Int>()

        var server: RPCServer {
            configurator.session.server
        }

        var sections: [Section] {
            [.gas, .description]
        }

        init(configurator: TransactionConfigurator, ethPrice: Subscribable<Double>) {
            self.configurator = configurator
            self.ethPrice = ethPrice
            self.session = configurator.session
        }

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let configuration: TransactionConfirmationHeaderView.Configuration = .init(isOpened: openedSections.contains(section), section: section, shouldHideChevron: !sections[section].isExpandable)
            let headerName = sections[section].title
            switch sections[section] {
            case .gas:
                let gasFee = gasFeeString(withConfigurator: configurator, cryptoToDollarRate: cryptoToDollarRate)
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, details: gasFee, configuration: configuration)
                } else {
                    return .init(title: .normal(configurationTitle), headerName: headerName, details: gasFee, configuration: configuration)
                }
            case .description:
                return .init(title: .normal(sections[section].title), headerName: nil, configuration: configuration)
            }
        }
    }

    class CancelTransactionViewModel: SectionProtocol {
        enum Section {
            case gas
            case description

            var title: String {
                switch self {
                case .gas:
                    return R.string.localizable.tokenTransactionConfirmationGasTitle()
                case .description:
                    return R.string.localizable.activityCancelDescription()
                }
            }

            var isExpandable: Bool {
                switch self {
                case .gas, .description:
                    return false
                }
            }
        }
        private let configurator: TransactionConfigurator
        private var configurationTitle: String {
            return configurator.selectedConfigurationType.title
        }
        let session: WalletSession
        let ethPrice: Subscribable<Double>
        var cryptoToDollarRate: Double?
        var openedSections = Set<Int>()

        var server: RPCServer {
            configurator.session.server
        }

        var sections: [Section] {
            [.gas, .description]
        }

        init(configurator: TransactionConfigurator, ethPrice: Subscribable<Double>) {
            self.configurator = configurator
            self.ethPrice = ethPrice
            self.session = configurator.session
        }

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let configuration: TransactionConfirmationHeaderView.Configuration = .init(isOpened: openedSections.contains(section), section: section, shouldHideChevron: !sections[section].isExpandable)
            let headerName = sections[section].title
            switch sections[section] {
            case .gas:
                let gasFee = gasFeeString(withConfigurator: configurator, cryptoToDollarRate: cryptoToDollarRate)
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, details: gasFee, configuration: configuration)
                } else {
                    return .init(title: .normal(configurationTitle), headerName: headerName, details: gasFee, configuration: configuration)
                }
            case .description:
                return .init(title: .normal(sections[section].title), headerName: nil, configuration: configuration)
            }
        }
    }
}

extension TransactionConfirmationViewModel {
    var navigationTitle: String {
        switch self {
        case .sendFungiblesTransaction, .sendNftTransaction:
            return R.string.localizable.tokenTransactionTransferConfirmationTitle()
        case .dappOrWalletConnectTransaction, .tokenScriptTransaction:
            return R.string.localizable.tokenTransactionConfirmationTitle()
        case .claimPaidErc875MagicLink:
            return R.string.localizable.tokenTransactionPurchaseConfirmationTitle()
        case .speedupTransaction:
            return R.string.localizable.tokenTransactionSpeedupConfirmationTitle()
        case .cancelTransaction:
            return R.string.localizable.tokenTransactionSpeedupConfirmationTitle()
        }
    }

    var title: String {
        return R.string.localizable.confirmPaymentConfirmButtonTitle()
    }
    var confirmationButtonTitle: String {
        switch self {
        case .dappOrWalletConnectTransaction, .tokenScriptTransaction, .sendFungiblesTransaction, .sendNftTransaction, .claimPaidErc875MagicLink:
            return R.string.localizable.confirmPaymentConfirmButtonTitle()
        case .speedupTransaction:
            return R.string.localizable.activitySpeedup()
        case .cancelTransaction:
            return R.string.localizable.tokenTransactionCancelConfirmationTitle()
        }
    }

    var backgroundColor: UIColor {
        return UIColor.clear
    }

    var footerBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var hasSeparatorAboveConfirmButton: Bool {
        switch self {
        case .sendFungiblesTransaction, .sendNftTransaction, .dappOrWalletConnectTransaction, .tokenScriptTransaction, .claimPaidErc875MagicLink:
            return true
        case .speedupTransaction, .cancelTransaction:
            return false
        }
    }
}
