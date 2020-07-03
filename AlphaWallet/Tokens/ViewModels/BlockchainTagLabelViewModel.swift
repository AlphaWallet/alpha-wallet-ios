//
//  BlockchainTagLabelViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import UIKit

struct BlockchainTagLabelViewModel {

    private let server: RPCServer

    init(server: RPCServer) {
        self.server = server
    }

    var blockChainNameFont: UIFont {
        return Screen.TokenCard.Font.blockChainName
    }

    var blockChainNameColor: UIColor {
        return Screen.TokenCard.Color.blockChainName
    }

    var blockChainNameBackgroundColor: UIColor {
        return server.blockChainNameColor
    }

    var blockChainTag: String {
        return server.name.uppercased()
    }

    var blockChainNameTextAlignment: NSTextAlignment {
        return .center
    }

    var blockChainNameCornerRadius: CGFloat {
        return Screen.TokenCard.Metric.blockChainTagCornerRadius
    }

    var blockChainName: String {
        return server.blockChainName
    }

    var blockChainNameLabelHidden: Bool {
        return !server.isTestnet
    }
}
