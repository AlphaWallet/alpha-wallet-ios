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
            lsh.separatorColor == rhs.separatorColor &&
            lsh.isSeparatorHidden == rhs.isSeparatorHidden &&
            lsh.count == rhs.count &&
            lsh.attributedCountValue == rhs.attributedCountValue
    }

    private let title: String?
    let value: String?
    let count: String?
    var attributedValue: NSAttributedString?
    var attributedCountValue: NSAttributedString?
    var separatorColor: UIColor = R.color.mercury()!
    var isSeparatorHidden: Bool = false

    init(title: String?, attributedValue: NSAttributedString?, attributedCountValue: NSAttributedString?, isSeparatorHidden: Bool = false) {
        self.title = title
        self.attributedValue = attributedValue
        self.attributedCountValue = attributedCountValue
        self.isSeparatorHidden = isSeparatorHidden
        self.value = attributedValue?.string
        self.count = attributedCountValue?.string
    }

    init(title: String?, attributedValue: NSAttributedString?, attributedCountValue: NSAttributedString?, value: String?, count: String?, isSeparatorHidden: Bool = false) {
        self.title = title
        self.attributedValue = attributedValue
        self.attributedCountValue = attributedCountValue
        self.isSeparatorHidden = isSeparatorHidden
        self.value = value
        self.count = count
    }

    var attributedTitle: NSAttributedString? {
        title.flatMap { TokenInstanceAttributeViewModel.defaultTitleAttributedString($0) }
    }
}
