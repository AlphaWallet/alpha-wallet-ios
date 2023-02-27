//
//  TokenAssetTableViewCellViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit
import AlphaWalletFoundation
import Combine

struct SelectableAssetContainerViewModel {
    private let selected: Int
    private let available: Int
    private let isSelected: Bool
    private let name: String

    var contentsBackgroundColor: UIColor? {
        return isSelected ? Configuration.Color.Semantic.tableViewSpecialBackground : Configuration.Color.Semantic.tableViewCellBackground
    }

    var titleAttributedString: NSAttributedString {
        return NSAttributedString(string: name, attributes: [
            .foregroundColor: Screen.TokenCard.Color.title,
            .font: Screen.TokenCard.Font.title
        ])
    }
    
    var descriptionAttributedString: NSAttributedString {
        return NSAttributedString(string: R.string.localizable.semifungiblesInfiniteFungibleToken(), attributes: [
            .foregroundColor: Screen.TokenCard.Color.subtitle,
            .font: Screen.TokenCard.Font.subtitle
        ])
    }

    var selectionImage: UIImage? {
        isSelected ? R.image.ticket_bundle_checked() : R.image.ticket_bundle_unchecked()
    }

    var selectionViewModel: AssetSelectionCircleOverlayViewModel {
        return AssetSelectionCircleOverlayViewModel(selected: selected, available: available, isSelected: isSelected)
    }

    init(selected: Int,
         available: Int,
         isSelected: Bool,
         name: String) {

        self.selected = selected
        self.available = available
        self.isSelected = isSelected
        self.name = name
    }

    var accessoryType: UITableViewCell.AccessoryType {
        return .disclosureIndicator
    }
}
