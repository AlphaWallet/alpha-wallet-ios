//
//  NonFungibleTraitViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.02.2022.
//

import UIKit

struct NonFungibleTraitViewModel: Equatable {

    static func == (lsh: NonFungibleTraitViewModel, rhs: NonFungibleTraitViewModel) -> Bool {
        return lsh.title == rhs.title &&
            lsh.attributedValue == rhs.attributedValue &&
            lsh.count == rhs.count &&
            lsh.attributedCountValue == rhs.attributedCountValue
    }

    private let title: String?
    let value: String?
    let count: String?
    var attributedValue: NSAttributedString?
    var attributedCountValue: NSAttributedString?
    var borderColor: UIColor = Colors.appTint
    var cornerRadius: CGFloat = 10
    var borderWidth: CGFloat = 1

    init(title: String?, attributedValue: NSAttributedString?, attributedCountValue: NSAttributedString?) {
        self.title = title
        self.attributedValue = attributedValue
        self.attributedCountValue = attributedCountValue
        self.value = attributedValue?.string
        self.count = attributedCountValue?.string
    }

    init(title: String?, attributedValue: NSAttributedString?, attributedCountValue: NSAttributedString?, value: String?, count: String?) {
        self.title = title
        self.attributedValue = attributedValue
        self.attributedCountValue = attributedCountValue
        self.value = value
        self.count = count
    }

    var attributedTitle: NSAttributedString? {
        title.flatMap { TokenAttributeViewModel.defaultTitleAttributedString($0, alignment: .center) }
    }
}
