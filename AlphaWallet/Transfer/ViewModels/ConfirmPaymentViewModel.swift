// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

struct ConfirmPaymentViewModel {

    var title: String {
        return R.string.localizable.confirmPaymentConfirmButtonTitle()
    }

    var sendButtonText: String {
        return R.string.localizable.send()
    }

    var backgroundColor: UIColor {
        return .white
    }
}
