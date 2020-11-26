//
//  TransactionConfirmationHeaderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.07.2020.
//

import UIKit

struct TransactionConfirmationHeaderViewModel {

    var title: String?
    var placeholder: String?
    var details: String?
    var configuration: TransactionConfirmationHeaderView.Configuration
    var chevronImage: UIImage? {
        let image = configuration.isOpened ? R.image.expand() : R.image.not_expand()
        return image?.withRenderingMode(.alwaysTemplate)
    }

    var titleAlpha: CGFloat {
        if configuration.shouldHideChevron {
            return 1.0
        } else {
            return configuration.isOpened ? 0.0 : 1.0
        }
    }

    var titleAttributedString: NSAttributedString? {
        guard let title = title else { return nil }

        return NSAttributedString(string: title, attributes: [
            .foregroundColor: Colors.black,
            .font: Fonts.regular(size: 17)
        ])
    }

    var placeholderAttributedString: NSAttributedString? {
        guard let placeholder = placeholder else { return nil }

        return NSAttributedString(string: placeholder, attributes: [
            .foregroundColor: R.color.dove()!,
            .font: Fonts.regular(size: 13)
        ])
    }

    var detailsAttributedString: NSAttributedString? {
        guard let details = details else { return nil }

        return NSAttributedString(string: details, attributes: [
            .foregroundColor: R.color.dove()!,
            .font: Fonts.regular(size: 13)
        ])
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }
}
