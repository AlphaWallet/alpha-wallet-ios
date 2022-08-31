//
//  SwitchCustomChainCallbackId.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation
import AlphaWalletFoundation

enum SwitchCustomChainCallbackId {
    case dapp(requestId: Int)
    case walletConnect(request: AlphaWallet.WalletConnect.Session.Request)
}
