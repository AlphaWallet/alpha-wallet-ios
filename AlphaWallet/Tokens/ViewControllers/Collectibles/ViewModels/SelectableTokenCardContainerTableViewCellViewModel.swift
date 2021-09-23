//
//  TokenAssetTableViewCellViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit

struct SelectableTokenCardContainerTableViewCellViewModel {
    private let token: Token?
    private let tokenHolder: TokenHolder
    private var title: String {
        return token?.name ?? "-"
    }

    var availableAmount: Int {
        //TODO check correct?
        return token?.amount ?? 1
    }

    var contentsBackgroundColor: UIColor {
        return selectionViewModel.isSelected ? R.color.solitude()! : Screen.TokenCard.Color.background
    }

    var titleAttributedString: NSAttributedString {
        return NSAttributedString(string: title, attributes: [
            .foregroundColor: Screen.TokenCard.Color.title,
            .font: Screen.TokenCard.Font.title
        ])
    }

    var descriptionAttributedString: NSAttributedString {
        return NSAttributedString(string: "Infinite Fungible Token", attributes: [
            .foregroundColor: Screen.TokenCard.Color.subtitle,
            .font: Screen.TokenCard.Font.subtitle
        ])
    }

    var iconImage: Subscribable<TokenImage> {
        .init(nil)
    }

    var selectionImage: UIImage? {
        selectionViewModel.isSelected ? R.image.ticket_bundle_checked() : R.image.ticket_bundle_unchecked()
    }

    var selectionViewModel: SingleTokenCardSelectionViewModel {
        .init(tokenHolder: tokenHolder, tokenId: tokenId)
    }
    private let tokenId: TokenId

    init(tokenHolder: TokenHolder, tokenId: TokenId) {
        self.token = tokenHolder.token(tokenId: tokenId)
        self.tokenId = tokenId
        self.tokenHolder = tokenHolder
    }

    var accessoryType: UITableViewCell.AccessoryType {
        return .disclosureIndicator
    }
}
