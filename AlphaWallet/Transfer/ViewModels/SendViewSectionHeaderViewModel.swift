//
//  SendViewSectionHeaderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.06.2020.
//

import UIKit

struct SendViewSectionHeaderViewModel {
    
    let text: String
    var showTopSeparatorLine: Bool = true
    
    var font: UIFont {
        return Fonts.bold(size: 15)
    }
    var textColor: UIColor {
        return Colors.headerThemeColor
    }
    var backgroundColor: UIColor {
        return Colors.clear
    }
    
    var separatorBackgroundColor: UIColor {
        return Colors.clear
    }
}

