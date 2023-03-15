// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletFoundation

enum ImportWalletParams {
    case json(json: String)
    case seedPhase(seedPhase: [String])
    case privateKey(privateKey: String)
}

enum WalletEntryPoint {
    case addInitialWallet
    case createInstantWallet
    case importWallet(params: ImportWalletParams?)
    case watchWallet(address: AlphaWallet.Address?)
    case addHardwareWallet
}
