//
//  ConfigureApp.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.05.2022.
//

import Foundation
import AlphaWalletOpenSea
import AlphaWalletENS

class ConfigureApp: Initializer {
    func perform() {
        ENS.isLoggingEnabled = true
        AlphaWalletOpenSea.OpenSea.isLoggingEnabled = true
    }
}
