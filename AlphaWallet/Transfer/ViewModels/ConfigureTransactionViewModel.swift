// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct ConfigureTransactionViewModel {
    private let server: RPCServer
    private let transferType: TransferType

    init(
        server: RPCServer,
        transferType: TransferType
    ) {
        self.server = server
        self.transferType = transferType
    }

    var title: String {
        return R.string.localizable.advanced()
    }

    var gasPriceFooterText: String {
        return R.string.localizable.configureTransactionGasPriceLabelDescription(server.name)
    }

    var gasLimitFooterText: String {
        return R.string.localizable.configureTransactionGasLimitLabelDescription(server.name)
    }

    var isDataInputHidden: Bool {
        switch transferType {
        case .nativeCryptocurrency, .dapp: return false
        case .ERC20Token: return true
        case .ERC875Token: return true
        case .ERC875TokenOrder: return true
        case .ERC721Token: return true
        case .ERC721ForTicketToken: return true
        }
    }
}
