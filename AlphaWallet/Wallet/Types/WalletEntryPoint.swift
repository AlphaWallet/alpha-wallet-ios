// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletFoundation

enum WalletEntryPoint {
    case addInitialWallet
    case createInstantWallet
    case importWallet
    case watchWallet(address: AlphaWallet.Address?)
}
