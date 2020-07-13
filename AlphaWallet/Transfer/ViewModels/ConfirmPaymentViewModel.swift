// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

enum ConfirmPaymentSection: Int, CaseIterable {
    case balance
    case recipient
    case gas
    case amount

    var title: String {
        switch self {
        case .balance:
            return "Balance"
        case .recipient:
            return "Recipient"
        case .gas:
            return "Speed (Gas)"
        case .amount:
            return "Amount"
        }
    }
}

struct ConfirmPaymentViewModel {

    var title: String {
        return R.string.localizable.confirmPaymentConfirmButtonTitle()
    }

    var sendButtonText: String {
        return R.string.localizable.send()
    }

    var backgroundColor: UIColor {
        return R.color.white()!
    } 
}
