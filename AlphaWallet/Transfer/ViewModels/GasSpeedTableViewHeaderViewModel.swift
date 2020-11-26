//
//  GasSpeedTableViewHeaderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.08.2020.
//

import UIKit

struct GasSpeedTableViewHeaderViewModel {
    private let title: String

    init(title: String) {
        self.title = title
    }

    var titleAttributedString: NSAttributedString {
        return NSAttributedString(string: title, attributes: [
            .foregroundColor: R.color.dove()!,
            .font: Fonts.regular(size: 15)
        ])
    }

    var backgroundColor: UIColor {
        return R.color.alabaster()!
    }
}
