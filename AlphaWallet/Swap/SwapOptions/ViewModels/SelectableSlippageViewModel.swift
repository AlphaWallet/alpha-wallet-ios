//
//  SelectableSlippageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import UIKit
import AlphaWalletFoundation

struct SelectableSlippageViewModel {
    let value: SwapSlippage
    var borderWidth: CGFloat = 1
    var borderColor: UIColor = .black
    var cornerRadius: CGFloat = 4.0
    var isSelected: Bool
    var backgroundColor: UIColor {
        return isSelected ? R.color.cod()! : Colors.appBackground
    }

    var titleAttributedString: NSAttributedString {
        let textColor: UIColor = isSelected ? .white: .black
        return .init(string: value.title, attributes: [
            .font: Fonts.regular(size: 17),
            .foregroundColor: textColor
        ])
    }
}
