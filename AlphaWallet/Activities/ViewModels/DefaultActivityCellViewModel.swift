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
        if activityStateViewViewModel.isInPendingState {
            return R.color.azure_sending()!
        } else {
            return .white
        }
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
            let string: NSMutableAttributedString
            switch activity.state {
            case .pending:
                string = NSMutableAttributedString(string: "\(R.string.localizable.activitySendPending(symbol))")
            case .completed:
                string = NSMutableAttributedString(string: "\(R.string.localizable.transactionCellSentTitle()) \(symbol)")
            case .failed:
                string = NSMutableAttributedString(string: "\(R.string.localizable.activitySendFailed(symbol))")
            }
            string.addAttribute(.font, value: Fonts.regular(size: 17), range: NSRange(location: 0, length: string.length))
            string.addAttribute(.font, value: Fonts.semibold(size: 17), range: NSRange(location: string.length - symbol.count, length: symbol.count))
            return string
        case .erc20Received, .erc721Received, .nativeCryptoReceived:
            let string = NSMutableAttributedString(string: "\(R.string.localizable.transactionCellReceivedTitle()) \(symbol)")
            string.addAttribute(.font, value: Fonts.regular(size: 17), range: NSRange(location: 0, length: string.length))
            string.addAttribute(.font, value: Fonts.semibold(size: 17), range: NSRange(location: string.length - symbol.count, length: symbol.count))
            return string
        case .erc20OwnerApproved, .erc721OwnerApproved:
            let string: NSMutableAttributedString
            switch activity.state {
            case .pending:
                string = NSMutableAttributedString(string: "\(R.string.localizable.activityOwnerApprovedPending(symbol))")
            case .completed:
                string = NSMutableAttributedString(string: R.string.localizable.activityOwnerApproved(symbol))
            case .failed:
                string = NSMutableAttributedString(string: "\(R.string.localizable.activityOwnerApprovedFailed(symbol))")
            }
            string.addAttribute(.font, value: Fonts.regular(size: 17), range: NSRange(location: 0, length: string.length))
            string.addAttribute(.font, value: Fonts.semibold(size: 17), range: NSRange(location: string.length - symbol.count, length: symbol.count))
            return string
        case .erc20ApprovalObtained, .erc721ApprovalObtained:
            let string = NSMutableAttributedString(string: R.string.localizable.activityApprovalObtained(symbol))
            string.addAttribute(.font, value: Fonts.regular(size: 17), range: NSRange(location: 0, length: string.length))
            string.addAttribute(.font, value: Fonts.semibold(size: 17), range: NSRange(location: string.length - symbol.count, length: symbol.count))
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
        Fonts.regular(size: 12)
    }

    var amount: NSAttributedString {
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

        let string: String
        switch activity.nativeViewType {
        case .erc20Sent, .erc20Received, .nativeCryptoSent, .nativeCryptoReceived:
            if let value = cardAttributes["amount"]?.uintValue {
                string = stringFromFungibleAmount(sign: sign, amount: value)
            } else {
                string = ""
            }
        case .erc20OwnerApproved, .erc20ApprovalObtained:
            if let value = cardAttributes["amount"]?.uintValue {
                if doesApprovedAmountLookReallyBig(value, decimals: activity.tokenObject.decimals) {
                    string = R.string.localizable.activityApproveAmountAll(activity.tokenObject.symbol)
                } else {
                    string = stringFromFungibleAmount(sign: sign, amount: value)
                }
            } else {
                string = ""
            }
        case .erc721Sent, .erc721Received, .erc721OwnerApproved, .erc721ApprovalObtained:
            if let value = cardAttributes["tokenId"]?.uintValue {
                string = "\(value)"
            } else {
                string = ""
            }
        case .none:
            string = ""
        }

        switch activity.state {
        case .pending:
            return NSAttributedString(string: string, attributes: [.font: Fonts.semibold(size: 17), .foregroundColor: R.color.black()!])
        case .completed:
            return NSAttributedString(string: string, attributes: [.font: Fonts.semibold(size: 17), .foregroundColor: R.color.black()!])
        case .failed:
            return NSAttributedString(string: string, attributes: [.font: Fonts.semibold(size: 17), .foregroundColor: R.color.silver()!, .strikethroughStyle: NSUnderlineStyle.single.rawValue])
        }
    }

    var timestampFont: UIFont {
        Fonts.regular(size: 12)
    }

    var timestampColor: UIColor {
        R.color.dove()!
    }
    private static let formatter: DateFormatter = Date.formatter(with: "dd MMM yyyy h:mm:ss a")
    var timestamp: String {
        if let date = cardAttributes["timestamp"]?.generalisedTimeValue?.date {
            let value = Self.formatter.string(from: date)
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

    var activityStateViewViewModel: ActivityStateViewViewModel {
        return .init(activity: activity)
    }

    private func stringFromFungibleAmount(sign: String, amount: BigUInt) -> String {
        let formatter = EtherNumberFormatter.short
        let value = formatter.string(from: BigInt(amount), decimals: activity.tokenObject.decimals)
        return "\(sign)\(value) \(activity.tokenObject.symbol)"
    }

    private func doesApprovedAmountLookReallyBig(_ amount: BigUInt, decimals: Int) -> Bool {
        let empiricallyBigLimit: Double = 90_000_000
        return Double(amount) / pow(10, activity.tokenObject.decimals).doubleValue > empiricallyBigLimit
    }

    var leftMargin: CGFloat {
        switch activity.rowType {
        case .standalone:
            return StyleLayout.sideMargin
        case .group:
            return StyleLayout.sideMargin
        case .item:
            return StyleLayout.sideMargin + 20
        }
    }
}
