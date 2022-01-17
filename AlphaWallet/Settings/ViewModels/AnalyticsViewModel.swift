//
//  AnalyticsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.01.2022.
//

import UIKit

struct AnalyticsViewModel {
    var image: UIImage? = R.image.iconsIllustrationsAnalytics()
    var navigationTitle: String = R.string.localizable.analyticsNavigationTitle()
    var isSendAnalyticsEnabled: Bool = true
    var attributedDescriptionString: NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        return NSAttributedString(string: R.string.localizable.analyticsDescription(), attributes: [
            .font: Fonts.regular(size: 17),
            .foregroundColor: Colors.black,
            .paragraphStyle: style,
        ])
    }
    var backgroundColor: UIColor = Colors.appBackground
    var switchViewModel: SwitchViewViewModel {
        .init(text: R.string.localizable.analyticsShareAnonymousData(), isOn: isSendAnalyticsEnabled)
    }
}
