//
//  SendNftTransactionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2022.
//

import UIKit
import BigInt
import AlphaWalletFoundation

extension TransactionConfirmationViewModel {
    class SendNftTransactionViewModel: ExpandableSection, RateUpdatable, BalanceUpdatable {
        private let configurator: TransactionConfigurator
        private let transactionType: TransactionType
        private let recipientResolver: RecipientResolver

        var ensName: String? { recipientResolver.ensName }
        var addressString: String? { recipientResolver.address?.eip55String }
        var openedSections = Set<Int>()
        var rate: CurrencyRate?
        var sections: [Section] {
            return Section.allCases
        }
        let session: WalletSession

        init(configurator: TransactionConfigurator,
             recipientResolver: RecipientResolver) {
            
            self.configurator = configurator
            self.transactionType = configurator.transaction.transactionType
            self.session = configurator.session
            self.recipientResolver = recipientResolver
        }

        func updateBalance(_ balanceViewModel: BalanceViewModel?) {
            //no-op
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

        func tokenIdAndValueViewModels() -> [String] {
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

        func generateViews() -> [ViewType] {
            var views: [ViewType] = []
            for (sectionIndex, section) in sections.enumerated() {
                switch section {
                case .recipient:
                    views += [.header(viewModel: buildHeaderViewModel(section: sectionIndex), isEditEnabled: false)]

                    for (rowIndex, row) in RecipientResolver.Row.allCases.enumerated() {
                        let isSubViewsHidden = isSubviewsHidden(section: sectionIndex, row: rowIndex)
                        switch row {
                        case .ens:
                            let vm = TransactionConfirmationRowInfoViewModel(title: R.string.localizable.transactionConfirmationRowTitleEns(), subtitle: ensName)
                            views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]
                        case .address:
                            let vm = TransactionConfirmationRowInfoViewModel(title: R.string.localizable.transactionConfirmationRowTitleWallet(), subtitle: addressString)
                            views += [.view(viewModel: vm, isHidden: isSubViewsHidden)]
                        }
                    }
                case .gas:
                    views += [.header(viewModel: buildHeaderViewModel(section: sectionIndex), isEditEnabled: configurator.session.server.canUserChangeGas)]
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
            let configuration: TransactionConfirmationHeaderView.Configuration = .init(
                    isOpened: openedSections.contains(section),
                    section: section,
                    shouldHideChevron: sections[section] != .recipient
            )

            let headerName = sections[section].title
            switch sections[section] {
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, configuration: configuration)
            case .gas:
                let gasFee = gasFeeString(for: configurator, rate: rate)
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, details: gasFee, configuration: configuration)
                } else {
                    return .init(title: .normal(configurator.selectedConfigurationType.title), headerName: headerName, details: gasFee, configuration: configuration)
                }
            case .tokenId:
                switch transactionType {
                case .erc1155Token:
                    let viewModels = tokenIdAndValueViewModels()
                    guard viewModels.count == 1 else {
                        return .init(title: .normal(nil), headerName: "Token IDs", configuration: configuration)
                    }

                    return .init(title: .normal(viewModels.first ?? "-"), headerName: headerName, configuration: configuration)
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
                    return .init(title: .normal(title), headerName: headerName, configuration: configuration)
                case .nativeCryptocurrency, .erc20Token, .prebuilt:
                    fatalError()
                }
            case .recipient:
                return .init(title: .normal(recipientResolver.value), headerName: headerName, configuration: configuration)
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
