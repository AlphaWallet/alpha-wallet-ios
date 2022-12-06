//
//  WalletPupupItemViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.03.2022.
//

import UIKit

struct WalletPupupItemViewModel {
    let attributedTitle: NSAttributedString
    let attributedDescription: NSAttributedString?
    let icon: UIImage?
    var highlightedBackgroundColor: UIColor = Configuration.Color.Semantic.defaultSubtitleText.withAlphaComponent(0.1)
    var normalBackgroundColor: UIColor = Configuration.Color.Semantic.defaultViewBackground

    init(title: String, description: String? = nil, icon: UIImage? = nil) {
        attributedTitle = .init(string: title, attributes: [
            .font: Fonts.regular(size: 20),
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText
        ])

        attributedDescription = description.flatMap {
            return NSAttributedString.init(string: $0, attributes: [
                .font: Fonts.regular(size: 15),
                .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText
            ])
        }

        self.icon = icon
    }
}
