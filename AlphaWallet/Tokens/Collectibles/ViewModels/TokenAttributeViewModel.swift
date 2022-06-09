//
//  TokenAttributeViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit

struct TokenAttributeViewModel: Equatable {

    static func == (lsh: TokenAttributeViewModel, rhs: TokenAttributeViewModel) -> Bool {
        return lsh.title == rhs.title &&
            lsh.attributedValue == rhs.attributedValue &&
            lsh.separatorColor == rhs.separatorColor &&
            lsh.isSeparatorHidden == rhs.isSeparatorHidden
    }

    private let title: String?
    let value: String?
    var attributedValue: NSAttributedString?
    var separatorColor: UIColor = R.color.mercury()!
    var isSeparatorHidden: Bool = false
    var valueLabelNumberOfLines: Int = 0

    init(title: String?, attributedValue: NSAttributedString?, isSeparatorHidden: Bool = false) {
        self.title = title
        self.attributedValue = attributedValue
        self.isSeparatorHidden = isSeparatorHidden
        self.value = attributedValue?.string
    }

    init(title: String?, attributedValue: NSAttributedString?, value: String?, isSeparatorHidden: Bool = false) {
        self.title = title
        self.attributedValue = attributedValue
        self.isSeparatorHidden = isSeparatorHidden
        self.value = value
    }

    var attributedTitle: NSAttributedString? {
        title.flatMap { Self.defaultTitleAttributedString($0) }
    }

    static func defaultTitleAttributedString(_ value: String, alignment: NSTextAlignment = .left, lineBreakMode: NSLineBreakMode = .byTruncatingTail) -> NSAttributedString {
        attributedString(value, alignment: alignment, font: Fonts.regular(size: 15), foregroundColor: R.color.dove()!, lineBreakMode: lineBreakMode)
    }

    static func defaultValueAttributedString(_ value: String, alignment: NSTextAlignment = .right, lineBreakMode: NSLineBreakMode = .byTruncatingTail) -> NSAttributedString {
        attributedString(value, alignment: alignment, font: Fonts.regular(size: 17), foregroundColor: Colors.black, lineBreakMode: lineBreakMode)
    }

    static func urlValueAttributedString(_ value: String, alignment: NSTextAlignment = .right, lineBreakMode: NSLineBreakMode = .byTruncatingTail) -> NSAttributedString {
        attributedString(value, alignment: alignment, font: Fonts.semibold(size: 17), foregroundColor: Colors.appTint, lineBreakMode: lineBreakMode)
    }

    static func boldValueAttributedString(_ value: String, alignment: NSTextAlignment = .right, lineBreakMode: NSLineBreakMode = .byTruncatingTail) -> NSAttributedString {
        attributedString(value, alignment: alignment, font: Screen.TokenCard.Font.valueChangeValue, foregroundColor: Colors.black, lineBreakMode: lineBreakMode)
    }

    static func attributedString(_ value: String, alignment: NSTextAlignment, font: UIFont, foregroundColor: UIColor, lineBreakMode: NSLineBreakMode) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = lineBreakMode
        
        return .init(string: value, attributes: [
            .font: font,
            .foregroundColor: foregroundColor,
            .paragraphStyle: paragraphStyle
        ])
    }
}
