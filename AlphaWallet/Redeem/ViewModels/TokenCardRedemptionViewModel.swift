//
//  TokenCardRedemptionViewModel.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/6/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit

struct TokenCardRedemptionViewModel {
    let token: TokenObject
    let tokenHolder: TokenHolder

    var headerTitle: String {
        return R.string.localizable.aWalletTokenRedeemShowQRCodeTitle()
    }

    var headerColor: UIColor {
        return Colors.appText
    }

    var headerFont: UIFont {
        return Fonts.regular(size: 28)!
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }
}
