//
//  ShowAddHideTokensViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2020.
//

import UIKit

struct ShowAddHideTokensViewModel {
    var addHideTokensIcon: UIImage?
    var addHideTokensTitle: String? = R.string.localizable.walletsAddHideTokensTitle()
    var addHideTokensTintColor: UIColor = Configuration.Color.Semantic.appTint
    var addHideTokensTintFont: UIFont = Fonts.semibold(size: 17)

    var addHideTokensAttributedString: NSAttributedString? {
        guard let string = addHideTokensTitle else { return .none }

        return .init(string: string, attributes: [
            .font: addHideTokensTintFont,
            .foregroundColor: addHideTokensTintColor
        ])
    }

    var titleAttributedString: NSAttributedString? = .none

    var badgeBackgroundColor: UIColor? {
        R.color.radical()
    }

    var backgroundColor: UIColor = Configuration.Color.Semantic.defaultViewBackground

    var badgeText: String?
}

extension ShowAddHideTokensViewModel {
    static func configuredForTestnet() -> ShowAddHideTokensViewModel {
        let titleAttributedString: NSAttributedString = .init(string: R.string.localizable.whereAreMyTokensTestnet(), attributes: [
           .font: Fonts.bold(size: 24),
           .foregroundColor: Configuration.Color.Semantic.defaultForegroundText
        ])
        return .init(addHideTokensTitle: R.string.localizable.whereAreMyTokensWhereAreMyTokens(), addHideTokensTintFont: Fonts.regular(size: 17), titleAttributedString: titleAttributedString)
    }
}
