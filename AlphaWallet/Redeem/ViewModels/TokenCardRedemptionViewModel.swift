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
    var token: TokenObject
    var tokenHolder: TokenHolder

    var headerTitle: String {
        return R.string.localizable.aWalletTokenRedeemShowQRCodeTitle()
    }

    var headerColor: UIColor {
        return Colors.appWhite
    }

    var headerFont: UIFont {
        return Fonts.light(size: 25)!
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }
}
