//
//  SwitchTableViewCellViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.06.2020.
//

import UIKit

struct SwitchTableViewCellViewModel {
    let titleText: String
    let icon: UIImage
    let value: Bool
    
    var titleFont: UIFont {
        return Fonts.regular(size: 17)!
    }
    
    var titleTextColor: UIColor {
        return Colors.black
    }
}
