//
//  AnalyticsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.01.2022.
//

import UIKit
import AlphaWalletFoundation

class AnalyticsViewModel {
    private var config: Config
    
    var image: UIImage? = R.image.iconsIllustrationsAnalytics()
    var title: String = R.string.localizable.analyticsNavigationTitle()
    var attributedDescriptionString: NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        return NSAttributedString(string: R.string.localizable.analyticsDescription(), attributes: [
            .font: Fonts.regular(size: 17),
            .foregroundColor: Configuration.Color.Semantic.tableViewCellPrimaryFont,
            .paragraphStyle: style,
        ])
    }
    var backgroundColor: UIColor = Configuration.Color.Semantic.defaultViewBackground
    var switchViewModel: SwitchViewViewModel {
        .init(text: R.string.localizable.analyticsShareAnonymousData(), isOn: config.sendAnalyticsEnabled ?? true)
    }

    init(config: Config) {
        self.config = config
    }

    func set(sendAnalyticsEnabled: Bool) {
        config.sendAnalyticsEnabled = sendAnalyticsEnabled
    }
}
