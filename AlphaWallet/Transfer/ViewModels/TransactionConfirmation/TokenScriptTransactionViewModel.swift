//
//  TokenScriptTransactionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2022.
//

import UIKit
import BigInt
import AlphaWalletFoundation

extension TransactionConfirmationViewModel {
    class TokenScriptTransactionViewModel: ExpandableSection, RateUpdatable, BalanceUpdatable {

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
        private let session: WalletSession
        private var formattedAmountValue: String {
            //FIXME: is here ether token?
            let amountToSend = (Decimal(bigUInt: configurator.transaction.value, decimals: configurator.session.server.decimals) ?? .zero).doubleValue
            let amount = NumberFormatter.shortCrypto.string(double: amountToSend) ?? "-"

            if let rate = rate {
                let amountInFiat = NumberFormatter.fiat(currency: rate.currency).string(double: amountToSend * rate.value) ?? "-"

                return "\(amount) \(configurator.session.server.symbol) ≈ \(amountInFiat)"
            } else {
                return "\(amount) \(configurator.session.server.symbol)"
            }
        }

        var rate: CurrencyRate?
        let functionCallMetaData: DecodedFunctionCall
        var openedSections = Set<Int>()
        var sections: [Section] {
            return Section.allCases
        }

        init(address: AlphaWallet.Address, configurator: TransactionConfigurator, functionCallMetaData: DecodedFunctionCall) {
            self.address = address
            self.configurator = configurator
            self.functionCallMetaData = functionCallMetaData
            self.session = configurator.session
        }

        func updateBalance(_ balanceViewModel: BalanceViewModel?) {
            //no-op
        }

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let configuration = TransactionConfirmationHeaderView.Configuration(isOpened: openedSections.contains(section), section: section, shouldHideChevron: sections[section] != .function)
            let headerName = sections[section].title
            switch sections[section] {
            case .gas:
                let gasFee = gasFeeString(for: configurator, rate: rate)
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
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, configuration: configuration)
            }
        }

        func isSubviewsHidden(section: Int) -> Bool {
            !openedSections.contains(section)
        }
    }
}
