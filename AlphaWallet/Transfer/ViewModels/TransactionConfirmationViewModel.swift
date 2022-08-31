// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine
import AlphaWalletFoundation

protocol CryptoToFiatRateUpdatable: class {
    var cryptoToDollarRate: Double? { get set }
}

protocol BalanceUpdatable: class {
    func updateBalance(_ balanceViewModel: BalanceViewModel?)
}

class TransactionConfirmationViewModel {
    private let session: WalletSession
    private lazy var token: AnyPublisher<Token, Never> = {
        let token = configurator.transaction.transactionType.tokenObject
        return Just(token)
            .eraseToAnyPublisher()
    }()
    private let configurationHasChangedSubject = PassthroughSubject<Void, Never>()
    private let reloadViewSubject = PassthroughSubject<Void, Never>()
    private let resolver: RecipientResolver
    private let configurator: TransactionConfigurator
    private (set) var canBeConfirmed = true
    private var timerToReenableConfirmButton: Timer?
    private let type: ViewModelType
    private let tokensService: TokenViewModelState
    var title: String = R.string.localizable.confirmPaymentConfirmButtonTitle()
    var backgroundColor: UIColor = UIColor.clear
    var footerBackgroundColor: UIColor = Colors.appWhite

    init(configurator: TransactionConfigurator, configuration: TransactionType.Configuration, assetDefinitionStore: AssetDefinitionStore, domainResolutionService: DomainResolutionServiceType, tokensService: TokenViewModelState) {
        self.tokensService = tokensService
        let recipientOrContract = configurator.transaction.recipient ?? configurator.transaction.contract
        resolver = RecipientResolver(address: recipientOrContract, domainResolutionService: domainResolutionService)
        self.configurator = configurator
        session = configurator.session

        switch configuration {
        case .tokenScriptTransaction(_, let contract, let functionCallMetaData):
            type = .tokenScriptTransaction(.init(address: contract, configurator: configurator, functionCallMetaData: functionCallMetaData))
        case .dappTransaction:
            type = .dappOrWalletConnectTransaction(.init(configurator: configurator, assetDefinitionStore: assetDefinitionStore, recipientResolver: resolver, requester: nil))
        case .walletConnect(_, let requester):
            type = .dappOrWalletConnectTransaction(.init(configurator: configurator, assetDefinitionStore: assetDefinitionStore, recipientResolver: resolver, requester: requester))
        case .sendFungiblesTransaction(_, let amount):
            let resolver = RecipientResolver(address: configurator.transaction.recipient, domainResolutionService: domainResolutionService)
            type = .sendFungiblesTransaction(.init(configurator: configurator, assetDefinitionStore: assetDefinitionStore, recipientResolver: resolver, amount: amount))
        case .sendNftTransaction(_, let tokenInstanceNames):
            let resolver = RecipientResolver(address: configurator.transaction.recipient, domainResolutionService: domainResolutionService)
            type = .sendNftTransaction(.init(configurator: configurator, recipientResolver: resolver, tokenInstanceNames: tokenInstanceNames))
        case .claimPaidErc875MagicLink(_, let price, let numberOfTokens):
            type = .claimPaidErc875MagicLink(.init(configurator: configurator, price: price, numberOfTokens: numberOfTokens))
        case .speedupTransaction:
            type = .speedupTransaction(.init(configurator: configurator))
        case .cancelTransaction:
            type = .cancelTransaction(.init(configurator: configurator))
        case .swapTransaction(let fromToken, let fromAmount, let toToken, let toAmount):
            type = .swapTransaction(.init(configurator: configurator, fromToken: fromToken, fromAmount: fromAmount, toToken: toToken, toAmount: toAmount))
        case .approve:
            //TODO rename `.dappOrWalletConnectTransaction` so it's more general?
            type = .dappOrWalletConnectTransaction(.init(configurator: configurator, assetDefinitionStore: assetDefinitionStore, recipientResolver: resolver, requester: nil))
        }
    }

    private lazy var resolvedRecipient: AnyPublisher<Void, Never> = {
        return resolver.resolveRecipient()
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }()

    private lazy var tokenBalance: AnyPublisher<BalanceViewModel?, Never> = {
        let forceTriggerUpdateBalance = configurationHasChangedSubject
            .flatMap { _ in self.token }
            .map { [tokensService] token -> TokenViewModel? in
                switch token.type {
                case .nativeCryptocurrency:
                    let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: token.server)
                    return tokensService.tokenViewModel(for: etherToken)
                case .erc20:
                    return tokensService.tokenViewModel(for: token)
                case .erc1155, .erc721, .erc875, .erc721ForTickets:
                    return tokensService.tokenViewModel(for: token)
                }
            }.map { $0?.balance }
            .eraseToAnyPublisher()

        let tokenBalance = token.flatMap { [tokensService] token -> AnyPublisher<TokenViewModel?, Never> in
            switch token.type {
            case .nativeCryptocurrency:
                let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: token.server)
                return tokensService.tokenViewModelPublisher(for: etherToken)
            case .erc20:
                return tokensService.tokenViewModelPublisher(for: token)
            case .erc1155, .erc721, .erc875, .erc721ForTickets:
                return tokensService.tokenViewModelPublisher(for: token)
            }
        }.map { $0?.balance }
        .eraseToAnyPublisher()

        return Publishers.Merge(tokenBalance, forceTriggerUpdateBalance)
            .handleEvents(receiveOutput: { [weak self] balance in
                self?.cryptoToFiatRateUpdatable.cryptoToDollarRate = balance?.ticker?.price_usd
                self?.updateBalance(balance)
            }).eraseToAnyPublisher()
    }()

    lazy var views: AnyPublisher<[ViewType], Never> = {
        let balanceUpdated = tokenBalance
            .mapToVoid()
            .eraseToAnyPublisher()

        let recipientUpdated = resolvedRecipient
            .mapToVoid()
            .eraseToAnyPublisher()

        let forceViewReload = reloadViewSubject.eraseToAnyPublisher()

        let initial = Just<Void>(()).eraseToAnyPublisher()

        return Publishers.Merge4(initial, balanceUpdated, recipientUpdated, forceViewReload)
            .map { _ in TransactionConfirmationViewModel.generateViews(for: self) }
            .eraseToAnyPublisher()
    }()

    var canUserChangeGas: Bool {
        configurator.session.server.canUserChangeGas
    }

    /// Method called when configuration has changes and we need to recalculate new balance value
    func updateBalance() {
        configurationHasChangedSubject.send(())
    }

    func reloadView() {
        reloadViewSubject.send(())
    }

    func reloadViewWithGasChanges() {
        reloadViewSubject.send(())
        disableConfirmButtonForShortTime()
    }

    func shouldShowChildren(for section: Int, index: Int) -> Bool {
        switch type {
        case .dappOrWalletConnectTransaction, .claimPaidErc875MagicLink, .tokenScriptTransaction, .speedupTransaction, .cancelTransaction, .swapTransaction:
            return true
        case .sendFungiblesTransaction(let viewModel):
            switch viewModel.sections[section] {
            case .recipient, .network:
                return !viewModel.isSubviewsHidden(section: section, row: index)
            case .gas, .amount, .balance:
                return true
            }
        case .sendNftTransaction(let viewModel):
            switch viewModel.sections[section] {
            case .recipient, .network:
                //NOTE: Here we need to make sure that this view is available to display
                return !viewModel.isSubviewsHidden(section: section, row: index)
            case .gas, .tokenId:
                return true
            }
        }
    }

    var cryptoToFiatRateUpdatable: CryptoToFiatRateUpdatable {
        switch type {
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

    func showHideSection(_ section: Int) -> Action {
        switch type {
        case .dappOrWalletConnectTransaction(let viewModel):
            return viewModel.showHideSection(section)
        case .tokenScriptTransaction(let viewModel):
            return viewModel.showHideSection(section)
        case .sendFungiblesTransaction(let viewModel):
            return viewModel.showHideSection(section)
        case .sendNftTransaction(let viewModel):
            return viewModel.showHideSection(section)
        case .claimPaidErc875MagicLink(let viewModel):
            return viewModel.showHideSection(section)
        case .speedupTransaction(let viewModel):
            return viewModel.showHideSection(section)
        case .cancelTransaction(let viewModel):
            return viewModel.showHideSection(section)
        case .swapTransaction(let viewModel):
            return viewModel.showHideSection(section)
        }
    }

    var navigationTitle: String {
        switch type {
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

    var confirmationButtonTitle: String {
        switch type {
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

    var hasSeparatorAboveConfirmButton: Bool {
        switch type {
        case .sendFungiblesTransaction, .sendNftTransaction, .dappOrWalletConnectTransaction, .tokenScriptTransaction, .claimPaidErc875MagicLink:
            return true
        case .speedupTransaction, .cancelTransaction, .swapTransaction:
            return false
        }
    }

    private func disableConfirmButtonForShortTime() {
        timerToReenableConfirmButton?.invalidate()
        let gap = TimeInterval(0.3)
        canBeConfirmed = false
        timerToReenableConfirmButton = Timer.scheduledTimer(withTimeInterval: gap, repeats: false) { [weak self] _ in
            self?.canBeConfirmed = true
        }
    }

    private func updateBalance(_ balanceViewModel: BalanceViewModel?) {
        switch type {
        case .dappOrWalletConnectTransaction(let viewModel):
            viewModel.updateBalance(balanceViewModel)
        case .tokenScriptTransaction(let viewModel):
            viewModel.updateBalance(balanceViewModel)
        case .sendFungiblesTransaction(let viewModel):
            viewModel.updateBalance(balanceViewModel)
        case .sendNftTransaction(let viewModel):
            viewModel.updateBalance(balanceViewModel)
        case .claimPaidErc875MagicLink(let viewModel):
            viewModel.updateBalance(balanceViewModel)
        case .speedupTransaction(let viewModel):
            viewModel.updateBalance(balanceViewModel)
        case .cancelTransaction(let viewModel):
            viewModel.updateBalance(balanceViewModel)
        case .swapTransaction(let viewModel):
            viewModel.updateBalance(balanceViewModel)
        }
    }
}

extension TransactionConfirmationViewModel {

    enum ViewType {
        case separator(height: CGFloat)
        case details(viewModel: TransactionRowDescriptionTableViewCellViewModel)
        case view(viewModel: TransactionConfirmationRowInfoViewModel, isHidden: Bool)
        case header(viewModel: TransactionConfirmationHeaderViewModel, isEditEnabled: Bool)
    }

    enum Action {
        case show
        case hide
    }

    enum ViewModelType {
        case dappOrWalletConnectTransaction(DappOrWalletConnectTransactionViewModel)
        case tokenScriptTransaction(TokenScriptTransactionViewModel)
        case sendFungiblesTransaction(SendFungiblesTransactionViewModel)
        case sendNftTransaction(SendNftTransactionViewModel)
        case claimPaidErc875MagicLink(ClaimPaidErc875MagicLinkViewModel)
        case speedupTransaction(SpeedupTransactionViewModel)
        case cancelTransaction(CancelTransactionViewModel)
        case swapTransaction(SwapTransactionViewModel)
    }

    static func gasFeeString(for configurator: TransactionConfigurator, cryptoToDollarRate: Double?) -> String {
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

    // swiftlint:disable function_body_length
    private static func generateViews(for _viewModel: TransactionConfirmationViewModel) -> [ViewType] {
        var views: [ViewType] = []

        switch _viewModel.type {
        case .dappOrWalletConnectTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                switch section {
                case .gas:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: _viewModel.canUserChangeGas)]
                case .amount, .network, .balance:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: false)]
                case .recipient:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: false)]
                    for (rowIndex, row) in RecipientResolver.Row.allCases.enumerated() {
                        let isSubViewsHidden = viewModel.isSubviewsHidden(section: sectionIndex, row: rowIndex)
                        switch row {
                        case .ens:
                            let vm = TransactionConfirmationRowInfoViewModel(title: R.string.localizable.transactionConfirmationRowTitleEns(), subtitle: viewModel.ensName)

                            views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]
                        case .address:
                            let vm = TransactionConfirmationRowInfoViewModel(title: R.string.localizable.transactionConfirmationRowTitleWallet(), subtitle: viewModel.addressString)

                            views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]
                        }
                    }
                case .function(let functionCallMetaData):
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: false)]

                    let isSubViewsHidden = viewModel.isSubviewsHidden(section: sectionIndex, row: 0)
                    let vm = TransactionConfirmationRowInfoViewModel(title: "\(functionCallMetaData.name)()", subtitle: "")
                    views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]
                    for arg in functionCallMetaData.arguments {
                        let vm = TransactionConfirmationRowInfoViewModel(title: arg.type.description, subtitle: arg.description)
                        views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]
                    }
                }
            }
        case .tokenScriptTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                switch section {
                case .gas:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: _viewModel.canUserChangeGas)]
                case .function:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: false)]

                    let isSubViewsHidden = viewModel.isSubviewsHidden(section: sectionIndex)
                    let vm = TransactionConfirmationRowInfoViewModel(title: "\(viewModel.functionCallMetaData.name)()", subtitle: "")

                    views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]

                    for arg in viewModel.functionCallMetaData.arguments {
                        let vm = TransactionConfirmationRowInfoViewModel(title: arg.type.description, subtitle: arg.description)
                        views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]
                    }
                case .contract, .amount, .network:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: false)]
                }
            }
        case .sendFungiblesTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                switch section {
                case .recipient:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: false)]

                    for (rowIndex, row) in RecipientResolver.Row.allCases.enumerated() {
                        let isSubViewsHidden = viewModel.isSubviewsHidden(section: sectionIndex, row: rowIndex)
                        switch row {
                        case .ens:
                            let vm = TransactionConfirmationRowInfoViewModel(title: R.string.localizable.transactionConfirmationRowTitleEns(), subtitle: viewModel.ensName)
                            views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]
                        case .address:
                            let vm = TransactionConfirmationRowInfoViewModel(title: R.string.localizable.transactionConfirmationRowTitleWallet(), subtitle: viewModel.addressString)

                            views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]
                        }
                    }
                case .gas:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: _viewModel.canUserChangeGas)]
                case .amount, .balance, .network:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: false)]
                }
            }
        case .sendNftTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                switch section {
                case .recipient:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: false)]

                    for (rowIndex, row) in RecipientResolver.Row.allCases.enumerated() {
                        let isSubViewsHidden = viewModel.isSubviewsHidden(section: sectionIndex, row: rowIndex)
                        switch row {
                        case .ens:
                            let vm = TransactionConfirmationRowInfoViewModel(title: R.string.localizable.transactionConfirmationRowTitleEns(), subtitle: viewModel.ensName)
                            views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]
                        case .address:
                            let vm = TransactionConfirmationRowInfoViewModel(title: R.string.localizable.transactionConfirmationRowTitleWallet(), subtitle: viewModel.addressString)
                            views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]
                        }
                    }
                case .gas:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: _viewModel.canUserChangeGas)]
                case .tokenId:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: false)]
                    //NOTE: Maybe its needed to update with something else
                    let tokenIdsAndValuesViews = viewModel.tokenIdAndValueViewModels().enumerated().map { (index, value) -> ViewType in
                        let vm = TransactionConfirmationRowInfoViewModel(title: value, subtitle: "")
                        let isSubviewsHidden = viewModel.isSubviewsHidden(section: sectionIndex, row: index)
                        return .view(viewModel: vm, isHidden: isSubviewsHidden)
                    }

                    views += [.separator(height: 20)]
                    views += tokenIdsAndValuesViews
                case .network:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: false)]
                }
            }
        case .claimPaidErc875MagicLink(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                switch section {
                case .gas:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: _viewModel.canUserChangeGas)]
                case .amount, .numberOfTokens, .network:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: false)]
                }
            }
        case .speedupTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                switch section {
                case .gas:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: _viewModel.canUserChangeGas)]
                case .description:
                    let vm = TransactionRowDescriptionTableViewCellViewModel(title: section.title)
                    views += [.details(viewModel: vm)]
                case .network:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: false)]
                }
            }
        case .cancelTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                switch section {
                case .gas:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: _viewModel.canUserChangeGas)]
                case .description:
                    let vm = TransactionRowDescriptionTableViewCellViewModel(title: section.title)
                    views += [.details(viewModel: vm)]
                case .network:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: false)]
                }
            }
        case .swapTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                switch section {
                case .gas:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: _viewModel.canUserChangeGas)]
                case .network, .from, .to:
                    views += [.header(viewModel: viewModel.headerViewModel(section: sectionIndex), isEditEnabled: false)]
                }
            }
        }

        return views
    }
    // swiftlint:enable function_body_length
}
