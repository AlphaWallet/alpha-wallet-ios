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
        return Fonts.semibold(size: 15)!
    }
    var textColor: UIColor {
        return R.color.dove()!
    }
    var backgroundColor: UIColor {
        return R.color.alabaster()!
    }
    
    var separatorBackgroundColor: UIColor {
        return R.color.mike()!
    }
}

