// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import Combine
import AlphaWalletFoundation

struct AccountViewModel {
    private let displayBalanceApprecation: Bool
    private let current: Wallet?
    private let accountRowViewModel: AccountsViewModel.AccountRowViewModel
    var wallet: Wallet { accountRowViewModel.wallet }

    var apprecation24hour: NSAttributedString {
        if displayBalanceApprecation {
            let style = NSMutableParagraphStyle()
            style.alignment = .right

            return .init(string: accountRowViewModel.balance.changePercentageString, attributes: [
                .font: Fonts.regular(size: 20),
                .foregroundColor: accountRowViewModel.balance.valuePercentageChangeColor,
                .paragraphStyle: style
            ])
        } else {
            return .init()
        }
    }

    var balance: NSAttributedString {
        return .init(string: accountRowViewModel.balance.totalAmountString, attributes: [
            .font: Fonts.bold(size: 20),
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText,
        ])
    }

    var blockieImage: BlockiesImage {
        accountRowViewModel.blockie
    }

    var addressOrEnsName: NSAttributedString {
        return .init(string: accountRowViewModel.addressOrEnsName, attributes: [
            .font: Fonts.regular(size: 12),
            .foregroundColor: Configuration.Color.Semantic.defaultAttributedString
        ])
    }

    init(displayBalanceApprecation: Bool, accountRowViewModel: AccountsViewModel.AccountRowViewModel, current: Wallet?) {
        self.accountRowViewModel = accountRowViewModel
        self.current = current
        self.displayBalanceApprecation = displayBalanceApprecation
    }

    var showWatchIcon: Bool {
        return accountRowViewModel.wallet.type == .watch(accountRowViewModel.wallet.address)
    }

    var isSelected: Bool {
        return accountRowViewModel.wallet == current
    }
}

extension BlockiesImage {
    static var defaulBlockieImage: BlockiesImage {
        return .image(image: R.image.tokenPlaceholderLarge()!, isEnsAvatar: false)
    }
}

extension WalletBalance {
    var valuePercentageChangeColor: UIColor {
        return TickerHelper(ticker: nil).valueChangeValueColor(from: change?.amount)
    }
}

extension AccountViewModel: Hashable { }
