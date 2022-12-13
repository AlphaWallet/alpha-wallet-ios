//
//  TokenCardRedemptionViewModel.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/6/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit
import AlphaWalletFoundation

struct TokenCardRedemptionViewModel {
    let token: Token
    let tokenHolder: TokenHolder

    var headerTitle: String {
        return R.string.localizable.aWalletTokenRedeemShowQRCodeTitle()
    }
}
