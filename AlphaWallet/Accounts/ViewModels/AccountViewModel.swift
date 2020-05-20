// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

struct AccountViewModel {
    private let server: RPCServer

    let wallet: Wallet
    let current: Wallet?
    let walletBalance: Balance?
    var ensName: String?
    
    init(wallet: Wallet, current: Wallet?, walletBalance: Balance?, ensName: String? = nil, server: RPCServer) {
        self.wallet = wallet
        self.current = current
        self.walletBalance = walletBalance
        self.ensName = ensName
        self.server = server
    }
    
    var showWatchIcon: Bool {
        return wallet.type == .watch(wallet.address)
    }
    var balance: String {
        let amount = walletBalance?.amountShort ?? "--"
        return "\(amount) \(server.symbol)"
    }
    var address: AlphaWallet.Address {
        return wallet.address
    }
    
    var icon: UIImage? {
        return R.image.xDai()
    }
    
    var selectionIcon: UIImage? {
        return isSelected ? R.image.check_mark() : nil
    }
    
    var isSelected: Bool {
        return wallet == current
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var balanceFont: UIFont {
        return Fonts.regular(size: 20)!
    }

    var addressFont: UIFont {
        return Fonts.regular(size: 12)!
    }

    var addressTextColor: UIColor {
        return R.color.dove()!
    }

    var addresses: String {
        if let ensName = ensName {
            return "\(ensName) | \(wallet.address.truncateMiddle)"
        } else {
            return wallet.address.truncateMiddle
        }
    }
}
