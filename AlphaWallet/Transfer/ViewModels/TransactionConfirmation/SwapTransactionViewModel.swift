//
//  SwapTransactionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2022.
//

import Foundation
import BigInt
import AlphaWalletFoundation

extension TransactionConfirmationViewModel {
    class SwapTransactionViewModel: SectionProtocol, CryptoToFiatRateUpdatable, BalanceUpdatable {
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
                let gasFee = gasFeeString(for: configurator, cryptoToDollarRate: cryptoToDollarRate)
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

        func updateBalance(_ balanceViewModel: BalanceViewModel?) {
            //no-op
        }
    }
}
