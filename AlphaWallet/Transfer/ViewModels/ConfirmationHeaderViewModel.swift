//
//  ConfirmationHeaderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.02.2021.
//

import UIKit

struct ConfirmationHeaderViewModel {
    let title: String
    var backgroundColor: UIColor {
        Colors.appBackground
    }
    var icon: UIImage? {
        return R.image.awLogoSmall()
    }
    var attributedTitle: NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        return .init(string: title, attributes: [
            .font: DataEntry.Font.text as Any,
            .paragraphStyle: style,
            .foregroundColor: Colors.darkGray
        ])
    }
}
