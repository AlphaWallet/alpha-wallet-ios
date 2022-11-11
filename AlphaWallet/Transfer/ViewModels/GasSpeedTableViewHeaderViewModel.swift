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
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText,
            .font: Fonts.regular(size: 13)
        ])
    }

    var backgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }
}
