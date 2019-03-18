// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct ConfigureTransactionViewModel {
    private let config: Config
    private let transferType: TransferType

    init(
        config: Config,
        transferType: TransferType
    ) {
        self.config = config
        self.transferType = transferType
    }

    var title: String {
        return R.string.localizable.advanced()
    }

    var gasPriceFooterText: String {
        return R.string.localizable.configureTransactionGasPriceLabelDescription(config.server.name)
    }

    var gasLimitFooterText: String {
        return R.string.localizable.configureTransactionGasLimitLabelDescription(config.server.name)
    }

    var isDataInputHidden: Bool {
        switch transferType {
        case .nativeCryptocurrency, .dapp: return false
        case .ERC20Token: return true
        case .ERC875Token: return true
        case .ERC875TokenOrder: return true
        case .ERC721Token: return true
        }
    }
}
