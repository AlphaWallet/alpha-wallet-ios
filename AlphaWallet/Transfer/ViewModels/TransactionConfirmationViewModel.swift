// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt

protocol CryptoToFiatRateUpdatable: class {
    var cryptoToDollarRate: Double? { get set }
}

enum TransactionConfirmationViewModel {
    case dappOrWalletConnectTransaction(DappOrWalletConnectTransactionViewModel)
    case tokenScriptTransaction(TokenScriptTransactionViewModel)
    case sendFungiblesTransaction(SendFungiblesTransactionViewModel)
    case sendNftTransaction(SendNftTransactionViewModel)
    case claimPaidErc875MagicLink(ClaimPaidErc875MagicLinkViewModel)
    case speedupTransaction(SpeedupTransactionViewModel)
    case cancelTransaction(CancelTransactionViewModel)
    case swapTransaction(SwapTransactionViewModel)

    init(configurator: TransactionConfigurator, configuration: TransactionConfirmationConfiguration, domainResolutionService: DomainResolutionServiceType) {
        switch configuration {
        case .tokenScriptTransaction(_, let contract, _, let functionCallMetaData):
            self = .tokenScriptTransaction(.init(address: contract, configurator: configurator, functionCallMetaData: functionCallMetaData))
        case .dappTransaction(_, _):
            self = .dappOrWalletConnectTransaction(.init(configurator: configurator, dappRequesterViewModel: nil))
        case .walletConnect(_, _, let dappRequesterViewModel):
            self = .dappOrWalletConnectTransaction(.init(configurator: configurator, dappRequesterViewModel: dappRequesterViewModel))
        case .sendFungiblesTransaction(_, _, let assetDefinitionStore, let amount):
            let resolver = RecipientResolver(address: configurator.transaction.recipient, domainResolutionService: domainResolutionService)
            self = .sendFungiblesTransaction(.init(configurator: configurator, assetDefinitionStore: assetDefinitionStore, recipientResolver: resolver, amount: amount))
        case .sendNftTransaction(_, _, let tokenInstanceNames):
            let resolver = RecipientResolver(address: configurator.transaction.recipient, domainResolutionService: domainResolutionService)
            self = .sendNftTransaction(.init(configurator: configurator, recipientResolver: resolver, tokenInstanceNames: tokenInstanceNames))
        case .claimPaidErc875MagicLink(_, _, let price, let numberOfTokens):
            self = .claimPaidErc875MagicLink(.init(configurator: configurator, price: price, numberOfTokens: numberOfTokens))
        case .speedupTransaction(_):
            self = .speedupTransaction(.init(configurator: configurator))
        case .cancelTransaction(_):
            self = .cancelTransaction(.init(configurator: configurator))
        case .swapTransaction(_, let fromToken, let fromAmount, let toToken, let toAmount):
            self = .swapTransaction(.init(configurator: configurator, fromToken: fromToken, fromAmount: fromAmount, toToken: toToken, toAmount: toAmount))
        case .approve:
            //TODO rename `.dappOrWalletConnectTransaction` so it's more general?
            self = .dappOrWalletConnectTransaction(.init(configurator: configurator, dappRequesterViewModel: nil))

        }
    }

    enum Action {
        case show
        case hide
    }

    var cryptoToFiatRateUpdatable: CryptoToFiatRateUpdatable {
        switch self {
        case .dappOrWalletConnectTransaction(let viewModel): return viewModel
        case .tokenScriptTransaction(let viewModel): return viewModel
        case .sendFungiblesTransaction(let viewModel): return viewModel
        case .sendNftTransaction(let viewModel): return viewModel
        case .claimPaidErc875MagicLink(let viewModel): return viewModel
        case .speedupTransaction(let viewModel): return viewModel
        case .cancelTransaction(let viewModel): return viewModel
        case .swapTransaction(let viewModel): return viewModel
        }
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
        case .swapTransaction(var viewModel):
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
    case nativeCryptocurrency(balanceViewModel: BalanceViewModel?)
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

        var cryptoToDollarRate: Double?
        var ensName: String? { recipientResolver.ensName }
        var addressString: String? { recipientResolver.address?.eip55String }
        var openedSections = Set<Int>()
        let transactionType: TransactionType
        let session: WalletSession
        let recipientResolver: RecipientResolver

        var server: RPCServer {
            configurator.session.server
        }

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
                shouldHideChevron: sections[section] != .recipient
            )
            let headerName = sections[section].title
            switch sections[section] {
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: .init(session.server.iconImage), configuration: configuration)
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

    class DappOrWalletConnectTransactionViewModel: SectionProtocol, CryptoToFiatRateUpdatable {
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
            return dappRequesterViewModel == nil ? R.image.awLogoSmall() : R.image.walletConnectIcon()
        }

        var dappIconUrl: URL? { dappRequesterViewModel?.dappIconUrl }

        private var dappRequesterViewModel: WalletConnectDappRequesterViewModel?

        init(configurator: TransactionConfigurator, dappRequesterViewModel: WalletConnectDappRequesterViewModel?) {
            self.configurator = configurator
            self.functionCallMetaData = configurator.transaction.data.flatMap { DecodedFunctionCall(data: $0) }
            self.session = configurator.session
            self.dappRequesterViewModel = dappRequesterViewModel
        }

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let configuration: TransactionConfirmationHeaderView.Configuration = .init(isOpened: openedSections.contains(section), section: section, shouldHideChevron: !sections[section].isExpandable)
            let headerName = sections[section].title
            switch sections[section] {
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: .init(session.server.iconImage), configuration: configuration)
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

    class TokenScriptTransactionViewModel: SectionProtocol, CryptoToFiatRateUpdatable {
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
        var openedSections = Set<Int>()
        var sections: [Section] {
            return Section.allCases
        }
        var server: RPCServer {
            configurator.session.server
        }
        let session: WalletSession

        init(address: AlphaWallet.Address, configurator: TransactionConfigurator, functionCallMetaData: DecodedFunctionCall) {
            self.address = address
            self.configurator = configurator
            self.functionCallMetaData = functionCallMetaData
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
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: .init(session.server.iconImage), configuration: configuration)
            }
        }

        func isSubviewsHidden(section: Int) -> Bool {
            !openedSections.contains(section)
        }
    }

    class SendNftTransactionViewModel: SectionProtocol, CryptoToFiatRateUpdatable {
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
        var sections: [Section] {
            return Section.allCases
        }
        let session: WalletSession

        init(configurator: TransactionConfigurator, recipientResolver: RecipientResolver, tokenInstanceNames: [TokenId: String]) {
            self.configurator = configurator
            self.transactionType = configurator.transaction.transactionType
            self.session = configurator.session
            self.recipientResolver = recipientResolver
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
                        return !recipientResolver.hasResolvedEnsName
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
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: .init(session.server.iconImage), configuration: configuration)
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
                case .nativeCryptocurrency, .erc20Token, .erc721Token, .claimPaidErc875MagicLink, .erc875Token, .erc875TokenOrder, .erc721ForTicketToken, .dapp, .tokenScript, .prebuilt:
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

    class ClaimPaidErc875MagicLinkViewModel: SectionProtocol, CryptoToFiatRateUpdatable {
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
        var cryptoToDollarRate: Double?

        var server: RPCServer {
            configurator.session.server
        }

        var sections: [Section] {
            return Section.allCases
        }

        init(configurator: TransactionConfigurator, price: BigUInt, numberOfTokens: UInt) {
            self.configurator = configurator
            self.price = price
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
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: .init(session.server.iconImage), configuration: configuration)
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

    class SpeedupTransactionViewModel: SectionProtocol, CryptoToFiatRateUpdatable {
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
        var cryptoToDollarRate: Double?
        var openedSections = Set<Int>()

        var server: RPCServer {
            configurator.session.server
        }

        var sections: [Section] {
            [.gas, .description]
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

    class CancelTransactionViewModel: SectionProtocol, CryptoToFiatRateUpdatable {
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
        var cryptoToDollarRate: Double?
        var openedSections = Set<Int>()

        var server: RPCServer {
            configurator.session.server
        }

        var sections: [Section] {
            [.gas, .description]
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

    class SwapTransactionViewModel: SectionProtocol, CryptoToFiatRateUpdatable {
        enum Section {
            case gas
            case network
            case from
            case to

            var title: String {
                switch self {
                case .gas:
                    return R.string.localizable.tokenTransactionConfirmationGasTitle()
                case .network:
                    return R.string.localizable.tokenTransactionConfirmationNetwork()
                case .from:
                    return R.string.localizable.transactionFromLabelTitle()
                case .to:
                    return R.string.localizable.transactionToLabelTitle()
                }
            }

            var isExpandable: Bool {
                return false
            }
        }
        private let configurator: TransactionConfigurator
        private let fromToken: TokenToSwap
        private let fromAmount: BigUInt
        private let toToken: TokenToSwap
        private let toAmount: BigUInt

        private var configurationTitle: String {
            return configurator.selectedConfigurationType.title
        }
        let session: WalletSession
        var cryptoToDollarRate: Double?
        var openedSections = Set<Int>()

        var server: RPCServer {
            configurator.session.server
        }

        var sections: [Section] {
            [.network, .gas, .from, .to]
        }

        init(configurator: TransactionConfigurator, fromToken: TokenToSwap, fromAmount: BigUInt, toToken: TokenToSwap, toAmount: BigUInt) {
            self.configurator = configurator
            self.fromToken = fromToken
            self.fromAmount = fromAmount
            self.toToken = toToken
            self.toAmount = toAmount
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
            case .from:
                let amount = EtherNumberFormatter.short.string(from: BigInt(fromAmount), decimals: fromToken.decimals)
                let symbol = fromToken.symbol
                return .init(title: .normal("\(amount) \(symbol)"), headerName: headerName, configuration: configuration)
            case .to:
                let amount = EtherNumberFormatter.short.string(from: BigInt(toAmount), decimals: toToken.decimals)
                let symbol = toToken.symbol
                return .init(title: .normal("\(amount) \(symbol)"), headerName: headerName, configuration: configuration)
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, configuration: configuration)
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
        case .swapTransaction:
            return R.string.localizable.tokenTransactionConfirmationTitle()
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
        case .swapTransaction:
            return R.string.localizable.confirmPaymentConfirmButtonTitle()
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
        case .speedupTransaction, .cancelTransaction, .swapTransaction:
            return false
        }
    }
}
