// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import BigInt

struct ActivityViewModel {
    let activity: Activity

    private var cardAttributes: [AttributeId: AssetInternalValue] {
        activity.values.card
    }

    var viewControllerTitle: String {
        R.string.localizable.activityTabbarItemTitle()
    }

    var backgroundColor: UIColor {
        Screen.TokenCard.Color.background
    }

    var titleTextColor: UIColor {
        R.color.black()!
    }

    var titleFont: UIFont {
        Fonts.regular(size: 20)!
    }

    var title: String {
        let symbol = activity.tokenObject.symbol
        switch activity.nativeViewType {
        case .erc20Sent, .erc721Sent, .nativeCryptoSent:
            return "\(R.string.localizable.transactionCellSentTitle()) \(symbol)"
        case .erc20Received, .erc721Received, .nativeCryptoReceived:
            return "\(R.string.localizable.transactionCellReceivedTitle()) \(symbol)"
        case .erc20OwnerApproved, .erc721OwnerApproved:
            return R.string.localizable.activityOwnerApproved(symbol)
        case .erc20ApprovalObtained, .erc721ApprovalObtained:
            return R.string.localizable.activityApprovalObtained(symbol)
        case .none:
            //Displaying the symbol is intentional
            return symbol
        }
    }

    var subTitle: String {
        switch activity.nativeViewType {
        case .erc20Sent, .erc721Sent, .nativeCryptoSent:
            if let address = cardAttributes["to"]?.addressValue?.truncateMiddle {
                return R.string.localizable.activityTo(address)
            } else {
                return ""
            }
        case .erc20Received, .erc721Received, .nativeCryptoReceived:
            if let address = cardAttributes["from"]?.addressValue?.truncateMiddle {
                return R.string.localizable.activityFrom(address)
            } else {
                return ""
            }
        case .erc20OwnerApproved, .erc721OwnerApproved:
            if let address = cardAttributes["spender"]?.addressValue?.truncateMiddle {
                return R.string.localizable.activityTo(address)
            } else {
                return ""
            }
        case .erc20ApprovalObtained, .erc721ApprovalObtained:
            if let address = cardAttributes["owner"]?.addressValue?.truncateMiddle {
                return R.string.localizable.activityFrom(address)
            } else {
                return ""
            }
        case .none:
            return ""
        }
    }

    var subTitleTextColor: UIColor {
        R.color.dove()!
    }

    var subTitleFont: UIFont {
        Fonts.regular(size: 12)!
    }

    var timestampFont: UIFont {
        Fonts.regular(size: 12)!
    }

    var timestampColor: UIColor {
        R.color.dove()!
    }

    var timestamp: String {
        if let date = cardAttributes["timestamp"]?.generalisedTimeValue?.date {
            let value = Date.formatter(with: "h:mm:ss | dd MMM yyyy").string(from: date)
            return "\(value)"
        } else {
            return ""
        }
    }

    var iconImage: Subscribable<TokenImage> {
        activity.tokenObject.icon
    }

    var stateImage: UIImage? {
        switch activity.state {
        case .completed:
            switch activity.nativeViewType {
            case .erc20Sent, .erc721Sent, .nativeCryptoSent:
                return R.image.activitySend()
            case .erc20Received, .erc721Received, .nativeCryptoReceived:
                return R.image.activityReceive()
            case .erc20OwnerApproved, .erc20ApprovalObtained, .erc721OwnerApproved, .erc721ApprovalObtained:
                return nil
            case .none:
                return nil
            }
        case .pending:
            return R.image.activityPending()
        case .failed:
            return R.image.activityFailed()
        }
    }
}