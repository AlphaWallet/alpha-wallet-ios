//
//  TextFieldViewViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.08.2020.
//

import UIKit

struct TextFieldViewViewModel {

    let placeholder: String?
    let value: String
    var keyboardType: UIKeyboardType = .default
    var allowEditing: Bool = true

    var shouldHidePlaceholder: Bool { return attributedPlaceholder == nil }
    var attributedPlaceholder: NSAttributedString? {
        guard let placeholder = placeholder else { return nil }

        return NSAttributedString(string: placeholder, attributes: [
            .foregroundColor: R.color.dove()!,
            .font: Fonts.regular(size: 13)
        ])
    }
}
