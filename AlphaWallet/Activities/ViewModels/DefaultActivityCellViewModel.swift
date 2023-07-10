// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import Combine
import AlphaWalletFoundation
import BigInt

struct DefaultActivityCellViewModel {
    private var server: RPCServer {
        activity.server
    }

    private var cardAttributes: [AttributeId: AssetInternalValue] {
         activity.values.card
    }

    let activity: Activity
    let tokenImageFetcher: TokenImageFetcher
    var contentsBackgroundColor: UIColor {
        if activityStateViewViewModel.isInPendingState {
            return Configuration.Color.Semantic.sendingState
        } else {
            return Configuration.Color.Semantic.tableViewCellBackground
        }
    }

    var backgroundColor: UIColor {
        Configuration.Color.Semantic.tableViewCellBackground
    }

    var titleTextColor: UIColor {
        Configuration.Color.Semantic.defaultForegroundText
    }

    var title: NSAttributedString {
        let symbol = activity.token.symbol
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
            if let address = cardAttributes.toAddressValue?.truncateMiddle {
                return R.string.localizable.activityTo(address)
            } else {
                return ""
            }
        case .erc20Received, .erc721Received, .nativeCryptoReceived:
            if let address = cardAttributes.fromAddressValue?.truncateMiddle {
                return R.string.localizable.activityFrom(address)
            } else {
                return ""
            }
        case .erc20OwnerApproved, .erc721OwnerApproved:
            if let address = cardAttributes.spenderAddressValue?.truncateMiddle {
                return R.string.localizable.activityTo(address)
            } else {
                return ""
            }
        case .erc20ApprovalObtained, .erc721ApprovalObtained:
            if let address = cardAttributes.ownerAddressValue?.truncateMiddle {
                return R.string.localizable.activityFrom(address)
            } else {
                return ""
            }
        case .none:
            return ""
        }
    }

    var subTitleTextColor: UIColor {
        Configuration.Color.Semantic.defaultSubtitleText
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
            if let value = cardAttributes.amountUIntValue {
                string = stringFromFungibleAmount(sign: sign, amount: value)
            } else {
                string = ""
            }
        case .erc20OwnerApproved, .erc20ApprovalObtained:
            if let value = cardAttributes.amountUIntValue {
                if doesApprovedAmountLookReallyBig(value, decimals: activity.token.decimals) {
                    string = R.string.localizable.activityApproveAmountAll(activity.token.symbol)
                } else {
                    string = stringFromFungibleAmount(sign: sign, amount: value)
                }
            } else {
                string = ""
            }
        case .erc721Sent, .erc721Received, .erc721OwnerApproved, .erc721ApprovalObtained:
            if let value = cardAttributes.tokenIdUIntValue {
                string = "\(value)"
            } else {
                string = ""
            }
        case .none:
            string = ""
        }

        switch activity.state {
        case .pending:
            return NSAttributedString(string: string, attributes: [.font: Fonts.semibold(size: 17), .foregroundColor: Configuration.Color.Semantic.defaultForegroundText])
        case .completed:
            return NSAttributedString(string: string, attributes: [.font: Fonts.semibold(size: 17), .foregroundColor: Configuration.Color.Semantic.defaultForegroundText])
        case .failed:
            return NSAttributedString(string: string, attributes: [.font: Fonts.semibold(size: 17), .foregroundColor: Configuration.Color.Semantic.textViewFailed, .strikethroughStyle: NSUnderlineStyle.single.rawValue])
        }
    }

    var timestampFont: UIFont {
        Fonts.regular(size: 12)
    }

    var timestampColor: UIColor {
        Configuration.Color.Semantic.defaultSubtitleText
    }
    private static let formatter: DateFormatter = Date.formatter(with: "dd MMM yyyy h:mm:ss a")
    var timestamp: String {
        if let date = cardAttributes.timestampGeneralisedTimeValue?.date {
            let value = Self.formatter.string(from: date)
            return "\(value)"
        } else {
            return ""
        }
    }

    var timestampTextAlignment: NSTextAlignment {
        .right
    }

    var iconImage: TokenImagePublisher {
        tokenImageFetcher.image(token: activity.token, size: .s120)
    }

    var activityStateViewViewModel: ActivityStateViewViewModel {
        return .init(activity: activity)
    }

    private func stringFromFungibleAmount(sign: String, amount: BigUInt) -> String {
        let formatter = EtherNumberFormatter.short
        let value = formatter.string(from: BigInt(amount), decimals: activity.token.decimals)
        return "\(sign)\(value) \(activity.token.symbol)"
    }

    private func doesApprovedAmountLookReallyBig(_ amount: BigUInt, decimals: Int) -> Bool {
        let empiricallyBigLimit: Double = 90_000_000
        return Double(amount) / pow(10, activity.token.decimals).doubleValue > empiricallyBigLimit
    }

    var leftMargin: CGFloat {
        switch activity.rowType {
        case .standalone:
            return DataEntry.Metric.sideMargin
        case .group:
            return DataEntry.Metric.sideMargin
        case .item:
            return DataEntry.Metric.sideMargin + 20
        }
    }
}
