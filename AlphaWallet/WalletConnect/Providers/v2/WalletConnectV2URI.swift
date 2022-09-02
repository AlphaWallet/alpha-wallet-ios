//
//  WalletConnectV2URI.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.11.2021.
//

import Foundation
import AlphaWalletFoundation

extension WalletConnectV2URI: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(absoluteString)
    }
} 
