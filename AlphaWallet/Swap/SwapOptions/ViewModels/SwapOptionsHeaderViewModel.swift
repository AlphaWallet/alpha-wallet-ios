//
//  SwapOptionsHeaderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.03.2022.
//

import UIKit

struct SwapOptionsHeaderViewModel {

    let title: String

    var attributedTitle: NSAttributedString {
        return NSAttributedString(string: title.uppercased(), attributes: [
            .font: Fonts.semibold(size: 15),
            .foregroundColor: R.color.dove()!
        ])
    }

}
