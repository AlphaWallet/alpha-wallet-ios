// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import BigInt

struct DefaultActivityCellViewModel {
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

    var titleTextColor: UIColor {
        R.color.black()!
    }

    var title: NSAttributedString {
        let symbol = activity.tokenObject.symbol
        switch activity.nativeViewType {
        case .erc20Sent, .erc721Sent, .nativeCryptoSent:
            let string = NSMutableAttributedString(string: "\(R.string.localizable.transactionCellSentTitle()) \(symbol)")
            string.addAttribute(.font, value: Fonts.regular(size: 17)!, range: NSRange(location: 0, length: string.length))
            string.addAttribute(.font, value: Fonts.semibold(size: 17)!, range: NSRange(location: string.length - symbol.count, length: symbol.count))
            return string
        case .erc20Received, .erc721Received, .nativeCryptoReceived:
            let string = NSMutableAttributedString(string: "\(R.string.localizable.transactionCellReceivedTitle()) \(symbol)")
            string.addAttribute(.font, value: Fonts.regular(size: 17)!, range: NSRange(location: 0, length: string.length))
            string.addAttribute(.font, value: Fonts.semibold(size: 17)!, range: NSRange(location: string.length - symbol.count, length: symbol.count))
            return string
        case .erc20OwnerApproved, .erc721OwnerApproved:
            let string = NSMutableAttributedString(string: R.string.localizable.activityOwnerApproved(symbol))
            string.addAttribute(.font, value: Fonts.regular(size: 17)!, range: NSRange(location: 0, length: string.length))
            string.addAttribute(.font, value: Fonts.semibold(size: 17)!, range: NSRange(location: string.length - symbol.count, length: symbol.count))
            return string
        case .erc20ApprovalObtained, .erc721ApprovalObtained:
            let string = NSMutableAttributedString(string: R.string.localizable.activityApprovalObtained(symbol))
            string.addAttribute(.font, value: Fonts.regular(size: 17)!, range: NSRange(location: 0, length: string.length))
            string.addAttribute(.font, value: Fonts.semibold(size: 17)!, range: NSRange(location: string.length - symbol.count, length: symbol.count))
            return string
        case .none:
            return .init()
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

    var amountFont: UIFont {
        Fonts.semibold(size: 17)!
    }

    var amount: String {
        let sign: String
        switch activity.nativeViewType {
        case .erc20Sent, .nativeCryptoSent:
            sign = "- "
        case .erc20Received, .nativeCryptoReceived:
            sign = "+ "
        case .erc20OwnerApproved, .erc20ApprovalObtained:
            sign = ""
        case .erc721Sent, .erc721Received, .erc721OwnerApproved, .erc721ApprovalObtained:
            sign = ""
        case .none:
            sign = ""
        }

        switch activity.nativeViewType {
        case .erc20Sent, .erc20Received, .erc20OwnerApproved, .erc20ApprovalObtained, .nativeCryptoSent, .nativeCryptoReceived:
            if let value = cardAttributes["amount"]?.uintValue {
                let formatter = EtherNumberFormatter.short
                let value = formatter.string(from: BigInt(value), decimals: activity.tokenObject.decimals)
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

    var timestampFont: UIFont {
        Fonts.regular(size: 12)!
    }

    var timestampColor: UIColor {
        R.color.dove()!
    }

    var timestamp: String {
        if let date = cardAttributes["timestamp"]?.generalisedTimeValue?.date {
            let value = Date.formatter(with: "h:mm a").string(from: date)
            return "\(value)"
        } else {
            return ""
        }
    }

    var timestampTextAlignment: NSTextAlignment {
        .right
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
