//
//  ClaimPaidErc875MagicLinkViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2022.
//

import Foundation
import BigInt
import AlphaWalletFoundation

extension TransactionConfirmationViewModel {
    class ClaimPaidErc875MagicLinkViewModel: ExpandableSection, RateUpdatable, BalanceUpdatable {
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

        private var formattedAmountValue: String {
            //NOTE: what actual token can be here? or its always native crypto, need to firegu out right `decimals` value, better to pass here actual NSDecimalNumber value
            let amountToSend = (Decimal(bigUInt: price, decimals: configurator.session.server.decimals) ?? .zero).doubleValue
            let amount = NumberFormatter.shortCrypto.string(double: amountToSend) ?? "-"

            if let rate = rate {
                let amountInFiat = NumberFormatter.fiat(currency: rate.currency).string(double: amountToSend * rate.value) ?? "-"

                return "\(amount) \(configurator.session.server.symbol) ≈ \(amountInFiat)"
            } else {
                return "\(amount) \(configurator.session.server.symbol)"
            }
        }

        var openedSections = Set<Int>()
        var rate: CurrencyRate?

        var sections: [Section] {
            return Section.allCases
        }

        init(configurator: TransactionConfigurator, price: BigUInt, numberOfTokens: UInt) {
            self.configurator = configurator
            self.price = price
            self.numberOfTokens = numberOfTokens
            self.session = configurator.session
        }

        func updateBalance(_ balanceViewModel: BalanceViewModel?) {
            //no-op
        }

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let configuration: TransactionConfirmationHeaderView.Configuration = .init(
                    isOpened: openedSections.contains(section),
                    section: section,
                    shouldHideChevron: true)

            let headerName = sections[section].title
            switch sections[section] {
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, configuration: configuration)
            case .gas:
                if let warning = configurator.gasPriceWarning {
                    return .init(title: .warning(warning.shortTitle), headerName: headerName, configuration: configuration)
                } else {
                    return .init(title: .normal(configurationTitle), headerName: headerName, configuration: configuration)
                }
            case .amount:
                return .init(title: .normal(formattedAmountValue), headerName: headerName, configuration: configuration)
            case .numberOfTokens:
                return .init(title: .normal(String(numberOfTokens)), headerName: headerName, configuration: configuration)
            }
        }
    }
}
