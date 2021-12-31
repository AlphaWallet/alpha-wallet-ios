//
//  TokenInstanceAttributeViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit

struct TokenInstanceAttributeViewModel: Equatable {

    static func == (lsh: TokenInstanceAttributeViewModel, rhs: TokenInstanceAttributeViewModel) -> Bool {
        return lsh.title == rhs.title &&
            lsh.attributedValue == rhs.attributedValue &&
            lsh.separatorColor == rhs.separatorColor &&
            lsh.isSeparatorHidden == rhs.isSeparatorHidden
    }

    private let title: String?
    var value: String? {
        attributedValue?.string
    }
    var attributedValue: NSAttributedString?
    var separatorColor: UIColor = R.color.mercury()!
    var isSeparatorHidden: Bool = false

    init(title: String?, attributedValue: NSAttributedString?, isSeparatorHidden: Bool = false) {
        self.title = title
        self.attributedValue = attributedValue
        self.isSeparatorHidden = isSeparatorHidden
    }

    var attributedTitle: NSAttributedString? {
        title.flatMap { Self.defaultTitleAttributedString($0) }
    }

    static func defaultTitleAttributedString(_ value: String, alignment: NSTextAlignment = .left) -> NSAttributedString {
        attributedString(value, alignment: alignment, font: Fonts.regular(size: 15), foregroundColor: R.color.dove()!)
    }

    static func defaultValueAttributedString(_ value: String, alignment: NSTextAlignment = .right) -> NSAttributedString {
        attributedString(value, alignment: alignment, font: Fonts.regular(size: 17), foregroundColor: Colors.black)
    }

    static func boldValueAttributedString(_ value: String, alignment: NSTextAlignment = .right) -> NSAttributedString {
        attributedString(value, alignment: alignment, font: Screen.TokenCard.Font.valueChangeValue, foregroundColor: Colors.black)
    }

    private static func attributedString(_ value: String, alignment: NSTextAlignment, font: UIFont, foregroundColor: UIColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment

        return .init(string: value, attributes: [
            .font: font,
            .foregroundColor: foregroundColor,
            .paragraphStyle: paragraphStyle
        ])
    }
}
