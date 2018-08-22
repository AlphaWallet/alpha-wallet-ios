// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct TransferTokensViewModel {

    var token: TokenObject
    var TokenHolders: [TokenHolder]

    init(token: TokenObject) {
        self.token = token
        self.TokenHolders = TokenAdaptor(token: token).getTokenHolders()
    }

    func item(for indexPath: IndexPath) -> TokenHolder {
        return TokenHolders[indexPath.row]
    }

    func numberOfItems(for section: Int) -> Int {
        return TokenHolders.count
    }

    func height(for section: Int) -> CGFloat {
        return 90
    }

    var title: String {
        return R.string.localizable.aWalletTokenTokenTransferSelectTokensTitle ()
    }

    var buttonTitleColor: UIColor {
        return Colors.appWhite
    }

    var buttonBackgroundColor: UIColor {
        return Colors.appHighlightGreen
    }

    var buttonFont: UIFont {
        return Fonts.regular(size: 20)!
    }

    func toggleSelection(for indexPath: IndexPath) -> [IndexPath] {
        let TokenHolder = item(for: indexPath)
        var changed = [indexPath]
        if TokenHolder.areDetailsVisible {
            TokenHolder.areDetailsVisible = false
            TokenHolder.isSelected = false
        } else {
            for (i, each) in TokenHolders.enumerated() where each.areDetailsVisible {
                each.areDetailsVisible = false
                each.isSelected = false
                changed.append(.init(row: i, section: indexPath.section))
            }
            TokenHolder.areDetailsVisible = true
            TokenHolder.isSelected = true
        }
        return changed
    }
}
