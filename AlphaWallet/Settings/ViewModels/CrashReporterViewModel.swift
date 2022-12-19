// Copyright © 2022 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

class CrashReporterViewModel {
    private var config: Config

    var image: UIImage? = R.image.iconsIllustrationsCrashReporting()
    var title: String = R.string.localizable.settingsCrashReporterTitle()
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
        .init(text: R.string.localizable.analyticsShareAnonymousData(), isOn: config.sendCrashReportingEnabled ?? true)
    }

    init(config: Config) {
        self.config = config
    }

    func set(sendCrashReportingEnabled: Bool) {
        config.sendCrashReportingEnabled = sendCrashReportingEnabled
    }
}
