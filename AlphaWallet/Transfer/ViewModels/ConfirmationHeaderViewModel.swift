//
//  ConfirmationHeaderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.02.2021.
//

import UIKit

struct ConfirmationHeaderViewModel {
    let title: String
    let isMinimalMode: Bool
    var backgroundColor: UIColor {
        Configuration.Color.Semantic.defaultViewBackground
    }
    var icon: UIImage? {
        return isMinimalMode ? nil : R.image.awLogoSmall()
    }
    var attributedTitle: NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        return .init(string: title, attributes: [
            .font: Fonts.semibold(size: 17) as Any,
            .paragraphStyle: style,
            .foregroundColor: Configuration.Color.Semantic.popupPrimaryFont
        ])
    }
    var swipeIndicationHidden: Bool

    init(title: String, isMinimalMode: Bool = false, swipeIndicationHidden: Bool = true) {
        self.title = title
        self.swipeIndicationHidden = swipeIndicationHidden
        self.isMinimalMode = isMinimalMode
    }
}
