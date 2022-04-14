// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import Combine

struct AccountViewModel {
    let wallet: Wallet
    let current: Wallet?
    let walletName: String?
    var ensName: String?
    let apprecation24hour: AnyPublisher<NSAttributedString, Never>
    let balance: AnyPublisher<NSAttributedString, Never>
    let blockiesImage: AnyPublisher<BlockiesImage, Never>

    init(wallet: Wallet, current: Wallet?, walletName: String?, apprecation24hour: AnyPublisher<NSAttributedString, Never>, balance: AnyPublisher<NSAttributedString, Never>, blockiesImage: AnyPublisher<BlockiesImage, Never>) {
        self.wallet = wallet
        self.current = current
        self.ensName = nil
        self.walletName = walletName
        self.apprecation24hour = apprecation24hour
        self.balance = balance
        self.blockiesImage = blockiesImage
    }

    var showWatchIcon: Bool {
        return wallet.type == .watch(wallet.address)
    }

    var address: AlphaWallet.Address {
        return wallet.address
    }

    var isSelected: Bool {
        return wallet == current
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    static func apprecation24hourAttributedString(for balance: WalletBalance?) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .right

        return .init(string: balance?.valuePercentageChangeValue ?? "-", attributes: [
            .font: Fonts.regular(size: 20),
            .foregroundColor: balance?.valuePercentageChangeColor ?? R.color.dove()!,
            .paragraphStyle: style
        ])
    }

    static func balanceAttributedString(for value: String?) -> NSAttributedString {
        return .init(string: value ?? "--", attributes: [
            .font: Fonts.bold(size: 20),
            .foregroundColor: Colors.black,
        ])
    }

    var addressesAttrinutedString: NSAttributedString {
        return .init(string: addresses, attributes: [
            .font: Fonts.regular(size: 12),
            .foregroundColor: R.color.dove()!
        ])
    }

    private var addresses: String {
        if let walletName = walletName {
            return "\(walletName) | \(wallet.address.truncateMiddle)"
        } else if let ensName = ensName {
            return "\(ensName) | \(wallet.address.truncateMiddle)"
        } else {
            return wallet.address.eip55String
        }
    }
} 
