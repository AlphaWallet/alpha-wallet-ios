//
//  TokensViewModel.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit

struct TokensViewModel {

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

    var buttonTitleColor: UIColor {
        return Colors.appWhite
    }

    var buttonBackgroundColor: UIColor {
        return Colors.appHighlightGreen
    }

    var buttonFont: UIFont {
        return Fonts.regular(size: 20)!
    }

    func toggleDetailsVisible(for indexPath: IndexPath) -> [IndexPath] {
        let TokenHolder = item(for: indexPath)
        var changed = [indexPath]
        if TokenHolder.areDetailsVisible {
            TokenHolder.areDetailsVisible = false
        } else {
            for (i, each) in TokenHolders.enumerated() where each.areDetailsVisible {
                each.areDetailsVisible = false
                changed.append(.init(row: i, section: indexPath.section))
            }
            TokenHolder.areDetailsVisible = true
        }
        return changed
    }
}
