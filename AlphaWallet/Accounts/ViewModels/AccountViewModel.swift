// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

struct AccountViewModel {
    private let server: RPCServer

    let wallet: Wallet
    let current: Wallet?
    let walletBalance: Balance?
    let walletName: String?
    var ensName: String?

    init(wallet: Wallet, current: Wallet?, walletBalance: Balance?, server: RPCServer, walletName: String?) {
        self.wallet = wallet
        self.current = current
        self.walletBalance = walletBalance
        self.ensName = nil
        self.server = server
        self.walletName = walletName
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

    var accessoryType: UITableViewCell.AccessoryType {
        return isSelected ? .checkmark : .none
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
        if let walletName = walletName {
            return "\(walletName) | \(wallet.address.truncateMiddle)"
        } else if let ensName = ensName {
            return "\(ensName) | \(wallet.address.truncateMiddle)"
        } else {
            return wallet.address.eip55String
        }
    }
}
