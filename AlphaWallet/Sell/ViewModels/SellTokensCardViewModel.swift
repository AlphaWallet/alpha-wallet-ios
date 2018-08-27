// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct SellTokensCardViewModel {

    var token: TokenObject
    var ticketHolders: [TokenHolder]

    init(token: TokenObject) {
        self.token = token
        self.ticketHolders = TokenAdaptor(token: token).getTicketHolders()
    }

    func item(for indexPath: IndexPath) -> TokenHolder {
        return ticketHolders[indexPath.row]
    }

    func numberOfItems(for section: Int) -> Int {
        return ticketHolders.count
    }

    var title: String {
        let tokenTypeName = XMLHandler(contract: token.address.eip55String).getTokenTypeName()
        return R.string.localizable.aWalletTicketTokenSellSelectTicketsTitle(tokenTypeName)
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
        let ticketHolder = item(for: indexPath)
        var changed = [indexPath]
        if ticketHolder.areDetailsVisible {
            ticketHolder.areDetailsVisible = false
            ticketHolder.isSelected = false
        } else {
            for (i, each) in ticketHolders.enumerated() where each.areDetailsVisible {
                each.areDetailsVisible = false
                each.isSelected = false
                changed.append(.init(row: i, section: indexPath.section))
            }
            ticketHolder.areDetailsVisible = true
            ticketHolder.isSelected = true
        }
        return changed
    }
}
