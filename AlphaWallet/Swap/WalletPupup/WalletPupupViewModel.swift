//
//  WalletPupupViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.03.2022.
//

import UIKit

struct WalletPupupViewModel {
    var actions: [PupupAction] = [.swap, .send, .receive, .buy]
    var backbroundColor: UIColor = Colors.appBackground
    var viewsSeparatorColor: UIColor = R.color.mercury()!
}
