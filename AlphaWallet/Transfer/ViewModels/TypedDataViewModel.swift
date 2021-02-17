//
//  TypedDataViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.03.2021.
//

import UIKit

struct TypedDataViewModel {
    var backgroundColor: UIColor = .white

    var nameAttributeString: NSAttributedString {
        return .init(string: name, attributes: [
            .font: Fonts.semibold(size: 13),
            .foregroundColor: R.color.dove()!
        ])
    }

    var valueAttributeString: NSAttributedString {
        return .init(string: value, attributes: [
            .font: Fonts.semibold(size: 17),
            .foregroundColor: Colors.black
        ])
    }

    var isCopyHidden: Bool {
        return !isCopyAllowed
    }

    private let name: String
    private let value: String
    private let isCopyAllowed: Bool

    init(name: String, value: String, isCopyAllowed: Bool = false) {
        self.name = name
        self.value = value
        self.isCopyAllowed = isCopyAllowed
    }
}
