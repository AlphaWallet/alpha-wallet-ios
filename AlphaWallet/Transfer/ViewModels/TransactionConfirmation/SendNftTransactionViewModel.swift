//
//  SendNftTransactionViewModel.swift
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
    class SendNftTransactionViewModel: TransactionConfirmationViewModelType {
        @Published private var etherCurrencyRate: Loadable<CurrencyRate, Error> = .loading

        private let configurator: TransactionConfigurator
        private let transactionType: TransactionType
        private let recipientResolver: RecipientResolver
        private let tokensService: TokensProcessingPipeline
        private var cancellable = Set<AnyCancellable>()
        private let session: WalletSession
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
            let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: session.server)
            tokensService.tokenViewModelPublisher(for: etherToken)
                .map { $0?.balance.ticker.flatMap { CurrencyRate(currency: $0.currency, value: $0.price_usd) } }
                .map { $0.flatMap { Loadable<CurrencyRate, Error>.done($0) } ?? .failure(SendFungiblesTransactionViewModel.NoCurrencyRateError()) }
                .assign(to: \.etherCurrencyRate, on: self, ownership: .weak)
                .store(in: &cancellable)

            let resolveRecipient = asFuture { await self.recipientResolver.resolveRecipient() }.eraseToAnyPublisher()
            let stateChanges = Publishers.CombineLatest($etherCurrencyRate, resolveRecipient).mapToVoid()

            let viewState = Publishers.Merge(stateChanges, configurator.objectChanges)
                .map { _ in
                    TransactionConfirmationViewModel.ViewState(
                        title: R.string.localizable.tokenTransactionTransferConfirmationTitle(),
                        views: self.buildTypedViews(),
                        isSeparatorHidden: false)
                }

            return TransactionConfirmationViewModelOutput(viewState: viewState.eraseToAnyPublisher())
        }

        func shouldShowChildren(for section: Int, index: Int) -> Bool {
            switch sections[section] {
            case .recipient, .network:
                //NOTE: Here we need to make sure that this view is available to display
                return !isSubviewsHidden(section: section, row: index)
            case .gas, .tokenId:
                return true
            }
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

        private var tokenHolders: [TokenHolder] {
            switch transactionType {
            case .erc1155Token(_, let tokenHolders):
                return tokenHolders
            case .erc721Token(_, let tokenHolders), .erc875Token(_, let tokenHolders), .erc721ForTicketToken(_, let tokenHolders):
                return tokenHolders
            case .nativeCryptocurrency, .erc20Token, .prebuilt:
                fatalError()
            }
        }

        private func tokenIdAndValueViewModels() -> [String] {
            let tokenIdsAndValues: [TokenSelection] = tokenHolders
                .flatMap { $0.selections }

            let tokenInstanceNames = tokenHolders
                .valuesAll
                .compactMapValues { $0.nameStringValue }

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
                case .tokenId:
                    views += [.header(viewModel: buildHeaderViewModel(section: sectionIndex), isEditEnabled: false)]
                    //NOTE: Maybe its needed to update with something else
                    let tokenIdsAndValuesViews = tokenIdAndValueViewModels().enumerated().map { (index, value) -> ViewType in
                        let vm = TransactionConfirmationRowInfoViewModel(title: value, subtitle: "")
                        let isSubviewsHidden = isSubviewsHidden(section: sectionIndex, row: index)
                        return .view(viewModel: vm, isHidden: isSubviewsHidden)
                    }
                    views += tokenIdsAndValuesViews
                case .network:
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
            case .gas:
                let gasFee = gasFeeString(for: configurator, rate: etherCurrencyRate.value)
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, details: gasFee, viewState: viewState)
                } else {
                    return .init(title: .normal(configurator.selectedGasSpeed.title), headerName: headerName, details: gasFee, viewState: viewState)
                }
            case .tokenId:
                switch transactionType {
                case .erc1155Token:
                    let viewModels = tokenIdAndValueViewModels()
                    guard viewModels.count == 1 else {
                        return .init(title: .normal(nil), headerName: "Token IDs", viewState: viewState)
                    }

                    return .init(title: .normal(viewModels.first ?? "-"), headerName: headerName, viewState: viewState)
                case .erc721Token, .erc875Token, .erc721ForTicketToken:
                    let tokenHolder = tokenHolders[0]

                    let tokenInstanceNames = tokenHolders
                        .valuesAll
                        .compactMapValues { $0.nameStringValue }

                    let tokenInstanceName = tokenInstanceNames[tokenHolder.tokenId]
                    let title: String
                    if let tokenInstanceName = tokenInstanceName, !tokenInstanceName.isEmpty {
                        title = "\(tokenInstanceName) (\(tokenHolder.tokenId))"
                    } else {
                        title = String(tokenHolder.tokenId)
                    }
                    return .init(title: .normal(title), headerName: headerName, viewState: viewState)
                case .nativeCryptocurrency, .erc20Token, .prebuilt:
                    fatalError()
                }
            case .recipient:
                return .init(title: .normal(recipientResolver.value), headerName: headerName, viewState: viewState)
            }
        }
    }
}

extension TransactionConfirmationViewModel.SendNftTransactionViewModel {
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
}
