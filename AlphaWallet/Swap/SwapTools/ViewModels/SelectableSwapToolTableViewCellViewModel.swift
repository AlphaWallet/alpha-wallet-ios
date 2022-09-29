//
//  SelectableSwapToolTableViewCellViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.09.2022.
//

import UIKit
import AlphaWalletFoundation

struct SelectableSwapToolTableViewCellViewModel: Hashable {
    let name: String
    let logoUrl: URL?
    let isSelected: Bool

    var accessoryImageView: UIImage? {
        return isSelected ? R.image.iconsSystemCheckboxOn() : R.image.iconsSystemCheckboxOff()
    }
    var logoPlaceholder: UIImage? { R.image.awLogoSmall() }
    var selectionStyle: UITableViewCell.SelectionStyle = .default
    var backgroundColor: UIColor = Colors.appBackground

    var infoViewModel: InformationViewModel {
        let title = NSAttributedString(string: name, attributes: [
            .font: Fonts.regular(size: 18),
            .foregroundColor: UIColor(red: 42, green: 42, blue: 42)
        ])
        let description = NSAttributedString(string: name, attributes: [
            .font: Fonts.regular(size: 16),
            .foregroundColor: UIColor(red: 42, green: 42, blue: 42)
        ])
        return InformationViewModel(title: title, description: description)
    }

    init(swapTool: SwapTool, isSelected: Bool) {
        self.isSelected = isSelected
        self.name = swapTool.name
        self.logoUrl = URL(string: swapTool.logoUrl)
    }
}
