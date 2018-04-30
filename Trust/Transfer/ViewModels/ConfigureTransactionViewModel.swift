// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct ConfigureTransactionViewModel {

    let config: Config
    let transferType: TransferType

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
        case .ether: return false
        case .token: return true
        case .stormBird: return true
        case .stormBirdOrder: return true
        }
    }
}
