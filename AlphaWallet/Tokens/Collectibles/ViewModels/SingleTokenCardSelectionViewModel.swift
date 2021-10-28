//
//  SingleTokenCardSelectionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit

struct SingleTokenCardSelectionViewModel {
    var backgroundColor: UIColor = Colors.appTint

    var selectedAmount: Int? {
        tokenHolder.selectedCount(tokenId: tokenId)
    }

    var isSelected: Bool {
        tokenHolder.isSelected(tokenId: tokenId)
    }

    var isSingleSelectionEnabled: Bool {
        //NOTE: not sure in the logic of displaying selection token amount view, maybe its need to be changed in some way
        guard let value = tokenHolder.token(tokenId: tokenId)?.value, value > 1 else {
            return true
        }
        return false
    }

    var isHidden: Bool {
        guard let value = tokenHolder.token(tokenId: tokenId)?.value, value > 1 else {
            return true
        }

        return selectedAmount == nil
    }

    let tokenId: TokenId
    let tokenHolder: TokenHolder

    init(tokenHolder: TokenHolder, tokenId: TokenId) {
        self.tokenId = tokenId
        self.tokenHolder = tokenHolder
    }

    var selectedAmountAttributedString: NSAttributedString? {
        guard let amount = selectedAmount else { return nil }

        return .init(string: "\(amount)", attributes: [
            .font: Fonts.semibold(size: 20),
            .foregroundColor: Colors.appWhite
        ])
    }
}
