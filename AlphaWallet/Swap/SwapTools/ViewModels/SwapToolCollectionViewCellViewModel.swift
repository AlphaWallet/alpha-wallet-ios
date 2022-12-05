//
//  SwapToolCollectionViewCellViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.09.2022.
//

import UIKit

struct SwapToolCollectionViewCellViewModel: Hashable {
    let name: String

    var nameAttributedString: NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        return NSAttributedString(string: name, attributes: [
            .paragraphStyle: style,
            .font: Fonts.regular(size: 18),
            .foregroundColor: Configuration.Color.Semantic.defaultInverseText
        ])
    }
}
