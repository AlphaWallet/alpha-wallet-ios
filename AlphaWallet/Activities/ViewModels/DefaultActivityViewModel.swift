// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import BigInt

struct DefaultActivityViewModel {
    private var server: RPCServer {
        activity.server
    }

    private var cardAttributes: [AttributeId: AssetInternalValue] {
        activity.values.card
    }

    let activity: Activity

    var contentsBackgroundColor: UIColor {
        .white
    }

    var backgroundColor: UIColor {
        Colors.appBackground
    }

    var amountFont: UIFont {
        Fonts.regular(size: 28)!
    }

    var amount: String {
        let sign: String
        switch activity.nativeViewType {
        case .erc20Sent, .nativeCryptoSent:
            sign = "- "
        case .erc20Received, .nativeCryptoReceived:
            sign = "+ "
        case .erc20OwnerApproved, .erc20ApprovalObtained, .erc721OwnerApproved, .erc721ApprovalObtained, .erc721Sent, .erc721Received:
            sign = ""
        case .none:
            sign = ""
        }

        switch activity.nativeViewType {
        case .erc20Sent, .erc20Received, .erc20OwnerApproved, .erc20ApprovalObtained, .nativeCryptoSent, .nativeCryptoReceived:
            if let value = cardAttributes["amount"]?.uintValue {
                let formatter = EtherNumberFormatter.short
                let value = formatter.string(from: BigInt(value))
                return "\(sign)\(value) \(activity.tokenObject.symbol)"
            } else {
                return ""
            }
        case .erc721Sent, .erc721Received, .erc721OwnerApproved, .erc721ApprovalObtained:
            if let value = cardAttributes["tokenId"]?.uintValue {
                return "\(value)"
            } else {
                return ""
            }
        case .none:
            return ""
        }
    }

    var amountColor: UIColor {
        R.color.black()!
    }
}
