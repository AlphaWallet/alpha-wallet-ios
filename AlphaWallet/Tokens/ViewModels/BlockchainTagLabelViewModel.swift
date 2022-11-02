//
//  BlockchainTagLabelViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import UIKit
import AlphaWalletFoundation

struct BlockchainTagLabelViewModel {

    private let server: RPCServer
    
    let isHidden: Bool

    init(server: RPCServer) {
        self.isHidden = !server.isTestnet
        self.server = server
    }

    init(server: RPCServer, isHidden: Bool) {
        self.isHidden = isHidden
        self.server = server
    }

    var backgroundColor: UIColor {
        return server.blockChainNameColor
    }

    var blockChainTag: String {
        return server.name.uppercased()
    }
}
