// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine
import AlphaWalletFoundation

protocol RateUpdatable: AnyObject {
    var rate: CurrencyRate? { get set }
}

protocol BalanceUpdatable: AnyObject {
    func updateBalance(_ balanceViewModel: BalanceViewModel?)
}

struct TransactionConfirmationViewModelInput {

}

struct TransactionConfirmationViewModelOutput {
    let viewState: AnyPublisher<TransactionConfirmationViewModel.ViewState, Never>
}

class TransactionConfirmationViewModel {
    private let configurationHasChangedSubject = PassthroughSubject<Void, Never>()
    private let reloadViewSubject = PassthroughSubject<Void, Never>()
    private let recipientResolver: RecipientResolver
    private let configurator: TransactionConfigurator
    private (set) var canBeConfirmed = true
    private var timerToReenableConfirmButton: Timer?
    private let type: ViewModelType
    private let tokensService: TokenViewModelState

    var backgroundColor: UIColor = Colors.clear
    var footerBackgroundColor: UIColor = Configuration.Color.Semantic.defaultViewBackground

    init(configurator: TransactionConfigurator, configuration: TransactionType.Configuration, assetDefinitionStore: AssetDefinitionStore, domainResolutionService: DomainResolutionServiceType, tokensService: TokenViewModelState) {
        self.tokensService = tokensService
        let recipientOrContract = configurator.transaction.recipient ?? configurator.transaction.contract
        recipientResolver = RecipientResolver(address: recipientOrContract, domainResolutionService: domainResolutionService)
        self.configurator = configurator

        switch configuration {
        case .tokenScriptTransaction(_, let contract, let functionCallMetaData):
            type = .tokenScriptTransaction(.init(address: contract, configurator: configurator, functionCallMetaData: functionCallMetaData))
        case .dappTransaction:
            type = .dappOrWalletConnectTransaction(.init(configurator: configurator, assetDefinitionStore: assetDefinitionStore, recipientResolver: recipientResolver, requester: nil))
        case .walletConnect(_, let requester):
            type = .dappOrWalletConnectTransaction(.init(configurator: configurator, assetDefinitionStore: assetDefinitionStore, recipientResolver: recipientResolver, requester: requester))
        case .sendFungiblesTransaction:
            type = .sendFungiblesTransaction(.init(configurator: configurator, assetDefinitionStore: assetDefinitionStore, recipientResolver: recipientResolver))
        case .sendNftTransaction:
            type = .sendNftTransaction(.init(configurator: configurator, recipientResolver: recipientResolver))
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
            type = .dappOrWalletConnectTransaction(.init(configurator: configurator, assetDefinitionStore: assetDefinitionStore, recipientResolver: recipientResolver, requester: nil))
        }
    }

    private lazy var resolvedRecipient: AnyPublisher<Void, Never> = {
        return recipientResolver.resolveRecipient()
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }()

    private lazy var tokenBalance: AnyPublisher<BalanceViewModel?, Never> = {
        //NOTE: isn't really correctly to handle this case, need to update it
        let forceTriggerUpdateBalance = configurationHasChangedSubject
            .flatMap { [configurator] _ -> AnyPublisher<Token, Never> in
                return .just(configurator.transaction.transactionType.tokenObject)
            }.map { [tokensService] token -> TokenViewModel? in
                switch token.type {
                case .nativeCryptocurrency:
                    let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: token.server)
                    return tokensService.tokenViewModel(for: etherToken)
                case .erc20, .erc1155, .erc721, .erc875, .erc721ForTickets:
                    return tokensService.tokenViewModel(for: token)
                }
            }.map { $0?.balance }

        let tokenBalance = Just(configurator.transaction.transactionType.tokenObject)
            .flatMap { [tokensService] token -> AnyPublisher<TokenViewModel?, Never> in
                switch token.type {
                case .nativeCryptocurrency:
                    let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: token.server)
                    return tokensService.tokenViewModelPublisher(for: etherToken)
                case .erc20, .erc1155, .erc721, .erc875, .erc721ForTickets:
                    return tokensService.tokenViewModelPublisher(for: token)
                }
            }.map { $0?.balance }

        return Publishers.Merge(tokenBalance, forceTriggerUpdateBalance)
            .handleEvents(receiveOutput: { [weak self] balance in
                self?.rateUpdatable.rate = balance?.ticker.flatMap { CurrencyRate(currency: $0.currency, value: $0.price_usd) }
                self?.updateBalance(balance)
            }).eraseToAnyPublisher()
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

    func transform(input: TransactionConfirmationViewModelInput) -> TransactionConfirmationViewModelOutput {
        let views = Publishers.Merge4(Just<Void>(()), tokenBalance.mapToVoid(), resolvedRecipient, reloadViewSubject)
            .map { _ in self.generateViews(for: self) }

        let viewState = views.map { TransactionConfirmationViewModel.ViewState(title: self.title, views: $0) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState)
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

    var rateUpdatable: RateUpdatable {
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

    func expandOrCollapseAction(for section: Int) -> ExpandOrCollapseAction {
        switch type {
        case .dappOrWalletConnectTransaction(let viewModel):
            return viewModel.expandOrCollapseAction(for: section)
        case .tokenScriptTransaction(let viewModel):
            return viewModel.expandOrCollapseAction(for: section)
        case .sendFungiblesTransaction(let viewModel):
            return viewModel.expandOrCollapseAction(for: section)
        case .sendNftTransaction(let viewModel):
            return viewModel.expandOrCollapseAction(for: section)
        case .claimPaidErc875MagicLink(let viewModel):
            return viewModel.expandOrCollapseAction(for: section)
        case .speedupTransaction(let viewModel):
            return viewModel.expandOrCollapseAction(for: section)
        case .cancelTransaction(let viewModel):
            return viewModel.expandOrCollapseAction(for: section)
        case .swapTransaction(let viewModel):
            return viewModel.expandOrCollapseAction(for: section)
        }
    }

    var title: String {
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
    struct ViewState {
        let title: String
        let views: [ViewType]
    }

    enum ViewType {
        case separator(height: CGFloat)
        case details(viewModel: TransactionRowDescriptionTableViewCellViewModel)
        case view(viewModel: TransactionConfirmationRowInfoViewModel, isHidden: Bool)
        case header(viewModel: TransactionConfirmationHeaderViewModel, isEditEnabled: Bool)
    }

    enum State {
        case ready
        case pending
        case done(withError: Bool)
    }

    enum ExpandOrCollapseAction {
        case expand
        case collapse
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

    static func gasFeeString(for configurator: TransactionConfigurator, rate: CurrencyRate?) -> String {
        let configuration = configurator.currentConfiguration
        let fee = Decimal(bigUInt: configuration.gasPrice * configuration.gasLimit, decimals: configurator.session.server.decimals) ?? .zero
        let estimatedProcessingTime = configurator.selectedConfigurationType.estimatedProcessingTime
        let feeString = NumberFormatter.shortCrypto.string(decimal: fee) ?? "-"
        let costs: String
        if let rate = rate {
            let amountInFiat = NumberFormatter.fiat(currency: rate.currency).string(double: fee.doubleValue * rate.value) ?? "-"

            costs =  "< ~\(feeString) \(configurator.session.server.symbol) (\(amountInFiat))"
        } else {
            costs = "< ~\(feeString) \(configurator.session.server.symbol)"
        }

        if estimatedProcessingTime.isEmpty {
            return costs
        } else {
            return "\(costs) \(estimatedProcessingTime)"
        }
    }

    // swiftlint:disable function_body_length
    private func generateViews(for _viewModel: TransactionConfirmationViewModel) -> [ViewType] {
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
