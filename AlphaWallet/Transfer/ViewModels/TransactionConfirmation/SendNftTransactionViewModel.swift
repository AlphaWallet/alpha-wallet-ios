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
    class SendNftTransactionViewModel: SectionProtocol, CryptoToFiatRateUpdatable, BalanceUpdatable {
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
        private let recipientResolver: RecipientResolver
        private var configurationTitle: String {
            configurator.selectedConfigurationType.title
        }

        var ensName: String? { recipientResolver.ensName }
        var addressString: String? { recipientResolver.address?.eip55String }
        var openedSections = Set<Int>()
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

        func updateBalance(_ balanceViewModel: BalanceViewModel?) {
            //no-op
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
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, configuration: configuration)
            case .gas:
                let gasFee = gasFeeString(for: configurator, cryptoToDollarRate: cryptoToDollarRate)
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
}
