//
//  SendFungiblesTransactionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2022.
//

import UIKit
import Combine
import AlphaWalletCore
import AlphaWalletFoundation
import BigInt

extension TransactionConfirmationViewModel {
    class SendFungiblesTransactionViewModel: TransactionConfirmationViewModelType {
        @Published private var transactedToken: Loadable<TransactedToken, Error> = .loading
        @Published private var balanceViewModel: TransactionBalance = .init(balance: .zero, newBalance: .zero, rate: nil)
        @Published private var etherCurrencyRate: Loadable<CurrencyRate, Error> = .loading

        private let configurator: TransactionConfigurator
        private let recipientResolver: RecipientResolver
        private let session: WalletSession
        private let tokensService: TokensProcessingPipeline
        private var cancellable = Set<AnyCancellable>()
        private let transactionType: TransactionType
        private var sections: [Section] { Section.allCases }

        let confirmButtonViewModel: ConfirmButtonViewModel
        var openedSections = Set<Int>()

        init(configurator: TransactionConfigurator,
             recipientResolver: RecipientResolver,
             tokensService: TokensProcessingPipeline) {

            self.tokensService = tokensService
            self.configurator = configurator
            self.transactionType = configurator.transaction.transactionType
            self.session = configurator.session
            self.recipientResolver = recipientResolver
            self.confirmButtonViewModel = ConfirmButtonViewModel(
                configurator: configurator,
                title: R.string.localizable.confirmPaymentConfirmButtonTitle())
        }

        func transform(input: TransactionConfirmationViewModelInput) -> TransactionConfirmationViewModelOutput {
            Just(transactionType.tokenObject)
                .flatMap { [tokensService] token -> AnyPublisher<TokenViewModel?, Never> in
                    switch token.type {
                    case .nativeCryptocurrency:
                        let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: token.server)
                        return tokensService.tokenViewModelPublisher(for: etherToken)
                    case .erc20, .erc1155, .erc721, .erc875, .erc721ForTickets:
                        return tokensService.tokenViewModelPublisher(for: token)
                    }
                }.map { [session] in $0.flatMap { TransactedToken(tokenViewModel: $0, session: session) } }
                .map { $0.flatMap { Loadable<TransactedToken, Error>.done($0) } ?? .failure(NoTokenError()) }
                .assign(to: \.transactedToken, on: self, ownership: .weak)
                .store(in: &cancellable)

            $transactedToken
                .compactMap { [weak self] in self?.buildTransactionBalance($0) }
                .assign(to: \.balanceViewModel, on: self, ownership: .weak)
                .store(in: &cancellable)

            let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: configurator.session.server)
            tokensService.tokenViewModelPublisher(for: etherToken)
                .map { $0?.balance.ticker.flatMap { CurrencyRate(currency: $0.currency, value: $0.price_usd) } }
                .map { $0.flatMap { Loadable<CurrencyRate, Error>.done($0) } ?? .failure(NoCurrencyRateError()) }
                .assign(to: \.etherCurrencyRate, on: self, ownership: .weak)
                .store(in: &cancellable)

            let resolveRecipient = asFuture { await self.recipientResolver.resolveRecipient() }.eraseToAnyPublisher()
            let stateChanges = Publishers.CombineLatest3($balanceViewModel, $etherCurrencyRate, resolveRecipient).mapToVoid()

            let viewState = Publishers.Merge(stateChanges, configurator.objectChanges)
                .compactMap { _ -> TransactionConfirmationViewModel.ViewState? in
                    return TransactionConfirmationViewModel.ViewState(
                        title: R.string.localizable.tokenTransactionTransferConfirmationTitle(),
                        views: self.buildTypedViews(),
                        isSeparatorHidden: false)
                }

            return TransactionConfirmationViewModelOutput(viewState: viewState.eraseToAnyPublisher())
        }

        func shouldShowChildren(for section: Int, index: Int) -> Bool {
            switch sections[section] {
            case .recipient, .network:
                return !isSubviewsHidden(section: section, row: index)
            case .gas, .amount, .balance:
                return true
            }
        }

        private func buildTransactionBalance(_ data: Loadable<TransactedToken, Error>) -> TransactionBalance {
            switch data {
            case .failure, .loading:
                return TransactionBalance(balance: .zero, newBalance: .zero, rate: nil)
            case .done(let token):
                let balance: Double
                let newBalance: Double

                switch token.type {
                case .nativeCryptocurrency, .erc20:
                    balance = token.balance.valueDecimal.doubleValue

                    var amountToSend: Double
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
                let rate = token.balance.ticker.flatMap { CurrencyRate(currency: $0.currency, value: $0.price_usd) }

                return TransactionBalance(balance: balance, newBalance: newBalance, rate: rate)
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
                    amountToSend = abs(balanceViewModel.balance - (Decimal(bigUInt: configurator.gasFee, decimals: token.decimals) ?? .zero).doubleValue)
                case .notSet, .none:
                    amountToSend = .zero
                }
            case .erc20Token:
                switch transactionType.amount {
                case .amount(let value):
                    amountToSend = value
                case .allFunds:
                    amountToSend = balanceViewModel.balance
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
                let symbol: String = transactedToken.value?.symbol ?? "-"
                //TODO: extract to constants
                let amount = NumberFormatter.shortCrypto.string(double: amountToSend, minimumFractionDigits: 4, maximumFractionDigits: 8)
                if let rate = balanceViewModel.rate {
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
            let symbol: String = transactedToken.value?.symbol ?? "-"
            let newBalance = NumberFormatter.shortCrypto.string(for: balanceViewModel.newBalance) ?? "-"

            return R.string.localizable.transactionConfirmationSendSectionBalanceNewTitle("\(newBalance) \(symbol)", symbol)
        }

        private var formattedBalanceString: String {
            let title = R.string.localizable.tokenTransactionConfirmationDefault()
            let symbol: String = transactedToken.value?.symbol ?? "-"
            let balance = NumberFormatter.alternateAmount.string(double: balanceViewModel.balance)

            return balance.flatMap { "\($0) \(symbol)" } ?? title
        }

        private func buildTypedViews() -> [ViewType] {
            var views: [ViewType] = []
            for (sectionIndex, section) in sections.enumerated() {
                switch section {
                case .recipient:
                    views += [.header(viewModel: buildHeaderViewModel(section: sectionIndex), isEditEnabled: false)]

                    for (rowIndex, row) in RecipientResolver.Row.allCases.enumerated() {
                        let isSubViewsHidden = isSubviewsHidden(section: sectionIndex, row: rowIndex)
                        switch row {
                        case .ens:
                            let vm = TransactionConfirmationRecipientRowInfoViewModel(
                                title: R.string.localizable.transactionConfirmationRowTitleEns(),
                                subtitle: recipientResolver.ensName,
                                blockieImage: recipientResolver.blockieImage)

                            views += [.recipient(viewModel: vm, isHidden: isSubViewsHidden)]
                        case .address:
                            let vm = TransactionConfirmationRowInfoViewModel(
                                title: R.string.localizable.transactionConfirmationRowTitleWallet(),
                                subtitle: recipientResolver.address?.eip55String)

                            views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]
                        }
                    }
                case .gas:
                    views += [.header(viewModel: buildHeaderViewModel(section: sectionIndex), isEditEnabled: session.server.canUserChangeGas)]
                case .amount, .balance, .network:
                    views += [.header(viewModel: buildHeaderViewModel(section: sectionIndex), isEditEnabled: false)]
                }
            }

            return views
        }

        private func buildHeaderViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let viewState = TransactionConfirmationHeaderViewModel.ViewState(
                isOpened: openedSections.contains(section),
                section: section,
                shouldHideChevron: sections[section] != .recipient)

            let headerName = sections[section].title

            switch sections[section] {
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, viewState: viewState)
            case .balance:
                return .init(title: .normal(formattedBalanceString), headerName: headerName, details: formattedNewBalanceString, viewState: viewState)
            case .gas:
                let gasFee = gasFeeString(for: configurator, rate: etherCurrencyRate.value)
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, details: gasFee, viewState: viewState)
                } else {
                    return .init(title: .normal(configurator.selectedGasSpeed.title), headerName: headerName, details: gasFee, viewState: viewState)
                }
            case .amount:
                return .init(title: .normal(formattedAmountValue), headerName: headerName, viewState: viewState)
            case .recipient:
                return .init(title: .normal(recipientResolver.value), headerName: headerName, viewState: viewState)
            }
        }
    }
}

extension TransactionConfirmationViewModel.SendFungiblesTransactionViewModel {
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

    struct NoTokenError: Error {}
    struct NoCurrencyRateError: Error {}

    struct TransactionBalance {
        let balance: Double
        let newBalance: Double
        let rate: CurrencyRate?
    }

    struct TransactedToken {
        let contract: AlphaWallet.Address
        let decimals: Int
        let name: String
        let symbol: String
        let type: TokenType
        let balance: BalanceViewModel

        init(tokenViewModel: TokenViewModel, session: WalletSession) {
            contract = tokenViewModel.contractAddress
            name = tokenViewModel.name
            decimals = tokenViewModel.decimals
            type = tokenViewModel.type
            balance = tokenViewModel.balance

            switch tokenViewModel.type {
            case .nativeCryptocurrency:
                symbol = tokenViewModel.symbol
            case .erc20, .erc1155, .erc721, .erc721ForTickets, .erc875:
                symbol = session.tokenAdaptor.tokenScriptOverrides(token: tokenViewModel).symbolInPluralForm
            }
        }
    }
}
