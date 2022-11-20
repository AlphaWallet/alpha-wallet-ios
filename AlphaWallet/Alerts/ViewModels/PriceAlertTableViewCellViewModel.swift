//
//  PriceAlertTableViewCellViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 19.11.2022.
//

import UIKit
import AlphaWalletFoundation

struct PriceAlertTableViewCellViewModel: Hashable {
    let alert: PriceAlert

    let titleAttributedString: NSAttributedString
    let icon: UIImage?
    let isSelected: Bool

    init(alert: PriceAlert) {
        self.alert = alert
        titleAttributedString = .init(string: alert.title, attributes: [
            .font: Fonts.regular(size: 17),
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText
        ])
        icon = alert.icon
        isSelected = alert.isEnabled
    }
}
