//
//  SpeedupTransactionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2022.
//

import Foundation
import BigInt
import AlphaWalletFoundation

extension TransactionConfirmationViewModel {
    class SpeedupTransactionViewModel: SectionProtocol, CryptoToFiatRateUpdatable, BalanceUpdatable {
        enum Section {
            case gas
            case network
            case description

            var title: String {
                switch self {
                case .gas:
                    return R.string.localizable.tokenTransactionConfirmationGasTitle()
                case .description:
                    return R.string.localizable.activitySpeedupDescription()
                case .network:
                    return R.string.localizable.tokenTransactionConfirmationNetwork()
                }
            }

            var isExpandable: Bool { return false }
        }
        private let configurator: TransactionConfigurator
        private var configurationTitle: String {
            return configurator.selectedConfigurationType.title
        }
        let session: WalletSession
        var cryptoToDollarRate: Double?
        var openedSections = Set<Int>()

        var sections: [Section] {
            [.gas, .network, .description]
        }

        init(configurator: TransactionConfigurator) {
            self.configurator = configurator
            self.session = configurator.session
        }

        func updateBalance(_ balanceViewModel: BalanceViewModel?) {
            //no-op
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
            case .network:
                return .init(title: .normal(session.server.displayName), headerName: headerName, titleIcon: session.server.walletConnectIconImage, configuration: configuration)
            case .description:
                return .init(title: .normal(sections[section].title), headerName: nil, configuration: configuration)
            }
        }
    }
}
