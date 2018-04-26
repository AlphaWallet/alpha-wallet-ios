// Copyright SIX DAY LLC. All rights reserved.
import Foundation
import UIKit

struct HelpUsViewModel {

    var title: String {
        return NSLocalizedString("welldone.navigation.title", value: "Thank you!", comment: "")
    }

    var activityItems: [Any] {
        return [
            R.string.localizable.welldoneViewmodelSharingText(),
            URL(string: Constants.website)!,
        ]
    }
}
