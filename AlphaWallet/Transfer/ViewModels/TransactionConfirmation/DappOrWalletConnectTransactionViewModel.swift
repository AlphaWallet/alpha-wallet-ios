//
//  DappOrWalletConnectTransactionViewModel.swift
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
    class DappOrWalletConnectTransactionViewModel: TransactionConfirmationViewModelType {
        @Published private var transactedToken: Loadable<SendFungiblesTransactionViewModel.TransactedToken, Error> = .loading
        @Published private var balanceViewModel: Loadable<SendFungiblesTransactionViewModel.TransactionBalance, Error> = .loading
        @Published private var etherCurrencyRate: Loadable<CurrencyRate, Error> = .loading

        private let configurator: TransactionConfigurator
        private let requester: RequesterViewModel?
        private let recipientResolver: RecipientResolver
        private let session: WalletSession
        private let transactionType: TransactionType
        private let functionCallMetaData: DecodedFunctionCall?
        private let tokensService: TokensProcessingPipeline
        private var cancellable = Set<AnyCancellable>()
        private var sections: [Section] {
            var sections: [Section]
            if let functionCallMetaData = functionCallMetaData {
                sections = [.balance, .gas, .amount, .network, .recipient, .function(functionCallMetaData)]
            } else {
                sections = [.balance, .gas, .amount, .network, .recipient]
            }
            if let requester = requester?.requester {
               sections += [.dapp(requester)]
            }

            return sections
        }

        let confirmButtonViewModel: ConfirmButtonViewModel
        var openedSections = Set<Int>()

        init(configurator: TransactionConfigurator,
             recipientResolver: RecipientResolver,
             requester: RequesterViewModel?,
             tokensService: TokensProcessingPipeline) {

            self.tokensService = tokensService
            self.recipientResolver = recipientResolver
            self.configurator = configurator
            self.functionCallMetaData = DecodedFunctionCall(data: configurator.transaction.data)
            self.session = configurator.session
            self.requester = requester
            self.transactionType = configurator.transaction.transactionType
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
                }.map { [session] in $0.flatMap { SendFungiblesTransactionViewModel.TransactedToken(tokenViewModel: $0, session: session) } }
                .map { $0.flatMap { Loadable<SendFungiblesTransactionViewModel.TransactedToken, Error>.done($0) } ?? .failure(NoTokenError()) }
                .assign(to: \.transactedToken, on: self, ownership: .weak)
                .store(in: &cancellable)

            $transactedToken
                .map { self.buildTransactionBalance($0) }
                .assign(to: \.balanceViewModel, on: self, ownership: .weak)
                .store(in: &cancellable)

            let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: configurator.session.server)
            tokensService.tokenViewModelPublisher(for: etherToken)
                .map { $0?.balance.ticker.flatMap { CurrencyRate(currency: $0.currency, value: $0.price_usd) } }
                .map { $0.flatMap { Loadable<CurrencyRate, Error>.done($0) } ?? .failure(SendFungiblesTransactionViewModel.NoCurrencyRateError()) }
                .assign(to: \.etherCurrencyRate, on: self, ownership: .weak)
                .store(in: &cancellable)

            let resolveRecipient = asFuture { await self.recipientResolver.resolveRecipient() }.eraseToAnyPublisher()
            let stateChanges = Publishers.CombineLatest3($balanceViewModel, $etherCurrencyRate, resolveRecipient).mapToVoid()

            let viewState = Publishers.Merge(stateChanges, configurator.objectChanges)
                .map { _ in
                    TransactionConfirmationViewModel.ViewState(
                        title: R.string.localizable.tokenTransactionConfirmationTitle(),
                        views: self.buildTypedViews(),
                        isSeparatorHidden: false)
                }

            return TransactionConfirmationViewModelOutput(
                viewState: viewState.eraseToAnyPublisher())
        }

        private func buildTransactionBalance(_ data: Loadable<SendFungiblesTransactionViewModel.TransactedToken, Error>) -> Loadable<SendFungiblesTransactionViewModel.TransactionBalance, Error> {
            return data.map { token in
                let balance: Double
                let newBalance: Double

                switch token.type {
                case .nativeCryptocurrency, .erc20:
                    balance = token.balance.valueDecimal.doubleValue
                    let amountToSend = (Decimal(bigUInt: configurator.transaction.value, decimals: token.decimals) ?? .zero).doubleValue
                    newBalance = abs(balance - amountToSend)
                case .erc1155, .erc721, .erc721ForTickets, .erc875:
                    balance = .zero
                    newBalance = .zero
                }

                let rate = token.balance.ticker.flatMap { CurrencyRate(currency: $0.currency, value: $0.price_usd) }
                let value = SendFungiblesTransactionViewModel.TransactionBalance(balance: balance, newBalance: newBalance, rate: rate)

                return .done(value)
            }
        }

        func shouldShowChildren(for section: Int, index: Int) -> Bool {
            return true
        }

        private var formattedNewBalanceString: String {
            guard let viewModel = balanceViewModel.value else { return "-" }

            let symbol = transactedToken.value?.symbol ?? "-"
            let newBalance = NumberFormatter.shortCrypto.string(for: viewModel.newBalance) ?? "-"

            return R.string.localizable.transactionConfirmationSendSectionBalanceNewTitle("\(newBalance) \(symbol)", "symbol")
        }

        private var formattedAmountValue: String {
            let amountToSend = (Decimal(bigUInt: configurator.transaction.value, decimals: configurator.session.server.decimals) ?? .zero).doubleValue
            //NOTE: previously it was full, make it full
            let amount = NumberFormatter.shortCrypto.string(double: amountToSend) ?? "-"

            if case .done(let rate) = etherCurrencyRate {
                let amountInFiat = NumberFormatter.fiat(currency: rate.currency).string(double: amountToSend * rate.value) ?? "-"
                return "\(amount) \(configurator.session.server.symbol) ≈ \(amountInFiat)"
            } else {
                return "\(amount) \(configurator.session.server.symbol)"
            }
        }

        private var formattedBalanceString: String {
            let title = R.string.localizable.tokenTransactionConfirmationDefault()
            guard let viewModel = balanceViewModel.value else { return title }

            let symbol = transactedToken.value?.symbol ?? "-"
            let balance = NumberFormatter.shortCrypto.string(for: viewModel.balance)

            return balance.flatMap { "\($0) \(symbol)" } ?? title
        }

        private func buildTypedViews() -> [ViewType] {
            var views: [ViewType] = []
            for (sectionIndex, section) in sections.enumerated() {
                switch section {
                case .gas:
                    views += [.header(viewModel: buildHeaderViewModel(section: sectionIndex), isEditEnabled: session.server.canUserChangeGas)]
                case .amount, .network, .balance, .dapp:
                    views += [.header(viewModel: buildHeaderViewModel(section: sectionIndex), isEditEnabled: false)]
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
                case .function(let functionCallMetaData):
                    views += [.header(viewModel: buildHeaderViewModel(section: sectionIndex), isEditEnabled: false)]

                    let isSubViewsHidden = isSubviewsHidden(section: sectionIndex, row: 0)
                    let vm = TransactionConfirmationRowInfoViewModel(title: "\(functionCallMetaData.name)()", subtitle: "")
                    views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]
                    for arg in functionCallMetaData.arguments {
                        let vm = TransactionConfirmationRowInfoViewModel(title: arg.type.description, subtitle: arg.description)
                        views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]
                    }
                }
            }

            return views
        }

        private func buildHeaderViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            func shouldHideChevron(for section: Int) -> Bool {
                switch sections[section] {
                case .recipient: return false
                default: return true
                }
            }

            let viewState = TransactionConfirmationHeaderViewModel.ViewState(
                isOpened: openedSections.contains(section),
                section: section,
                shouldHideChevron: shouldHideChevron(for: section))

            let headerName = sections[section].title
            switch sections[section] {
            case .balance:
                return .init(title: .normal(formattedBalanceString), headerName: headerName, details: formattedNewBalanceString, viewState: viewState)
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, viewState: viewState)
            case .gas:
                let gasFee = gasFeeString(for: configurator, rate: etherCurrencyRate.value)
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, details: gasFee, viewState: viewState)
                } else {
                    return .init(title: .normal(configurator.selectedGasSpeed.title), headerName: headerName, details: gasFee, viewState: viewState)
                }
            case .amount:
                return .init(title: .normal(formattedAmountValue), headerName: headerName, viewState: viewState)
            case .function(let functionCallMetaData):
                return .init(title: .normal(functionCallMetaData.name), headerName: headerName, viewState: viewState)
            case .recipient:
                return .init(title: .normal(recipientResolver.value), headerName: headerName, viewState: viewState)
            case .dapp(let requester):
                let dapp = requester.shortName.nilIfEmpty ?? requester.name.nilIfEmpty ?? requester.url?.absoluteString ?? "-"
                let titleIcon = requester.iconUrl.flatMap { ImageOrWebImageUrl<Image>.url(WebImageURL(url: $0)) }

                return .init(title: .normal(dapp), headerName: headerName, titleIcon: .just(titleIcon), viewState: viewState)
            }
        }

        func isSubviewsHidden(section: Int, row: Int) -> Bool {
            let isOpened = openedSections.contains(section)
            switch sections[section] {
            case .balance, .gas, .amount, .network, .function, .dapp:
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

extension TransactionConfirmationViewModel.DappOrWalletConnectTransactionViewModel {
    enum Section {
        case balance
        case gas
        case network
        case amount
        case recipient
        case dapp(Requester)
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
            case .dapp:
                return R.string.localizable.transactionConfirmationSendSectionRequesterTitle()
            }
        }

        var isExpandable: Bool {
            switch self {
            case .gas, .amount, .network, .balance, .dapp:
                return false
            case .function, .recipient:
                return true
            }
        }
    }
}
