// Copyright SIX DAY LLC. All rights reserved.
import Foundation
import UIKit

struct HelpUsViewModel {
    var title: String {
        return R.string.localizable.welldoneNavigationTitle(preferredLanguages: Languages.preferred())
    }

    var activityItems: [Any] {
        return [
            R.string.localizable.welldoneViewmodelSharingText(preferredLanguages: Languages.preferred()),
            URL(string: Constants.website)!,
        ]
    }
}
