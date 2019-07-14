// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum WalletEntryPoint {
    case welcome
    case createInstantWallet
    case importWallet
    case watchWallet
    case backupWallet(address: AlphaWallet.Address)
}
