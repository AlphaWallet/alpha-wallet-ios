//
//  TransactionDeadlineTextFieldModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import UIKit
import AlphaWalletFoundation

struct TransactionDeadlineTextFieldModel {
    private let value: TransactionDeadline

    init(value: TransactionDeadline) {
        self.value = value
    }

    var titleAttributedString: NSAttributedString {
        return .init(string: "minutes", attributes: [
            .font: Fonts.regular(size: 14),
            .foregroundColor: R.color.mine()!
        ])
    }

    var placeholderString: String { return "0" }

    var valueString: String {
        switch value {
        case .value(let value):
            return String(value)
        case .undefined:
            return ""
        }
    }
}
