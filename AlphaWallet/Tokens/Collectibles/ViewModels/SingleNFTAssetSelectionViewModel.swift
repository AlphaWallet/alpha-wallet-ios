//
//  AssetSelectionCircleOverlayViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit
import AlphaWalletFoundation

struct AssetSelectionCircleOverlayViewModel {
    private let selected: Int
    private let available: Int
    private let isSelected: Bool
    
    var isHidden: Bool { available <= 1 }

    init(selected: Int,
         available: Int,
         isSelected: Bool) {

        self.selected = selected
        self.available = available
        self.isSelected = isSelected
    }

    var selectedAmountAttributedString: NSAttributedString {
        return .init(string: String(selected), attributes: [
            .font: Fonts.semibold(size: 20),
            .foregroundColor: Configuration.Color.Semantic.defaultInverseText
        ])
    }
}
