// Copyright © 2020 Stormbird PTE. LTD.

import Combine
import Foundation
import UIKit
import AlphaWalletFoundation
import BigInt

struct ActivityViewModel {
    let activity: Activity
    let tokenImageFetcher: TokenImageFetcher

    private var cardAttributes: [AttributeId: AssetInternalValue] {
        activity.values.card
    }

    var viewControllerTitle: String {
        R.string.localizable.activityTabbarItemTitle()
    }

    var backgroundColor: UIColor {
        Configuration.Color.Semantic.defaultViewBackground
    }

    var titleTextColor: UIColor {
        Configuration.Color.Semantic.defaultTitleText
    }

    var titleFont: UIFont {
        Fonts.regular(size: 20)
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
            return string
        case .erc20Received, .erc721Received, .nativeCryptoReceived:
            return NSAttributedString(string: "\(R.string.localizable.transactionCellReceivedTitle()) \(symbol)")
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
            return string
        case .erc20ApprovalObtained, .erc721ApprovalObtained:
            return NSAttributedString(string: R.string.localizable.activityApprovalObtained(symbol))
        case .none:
            //Displaying the symbol is intentional
            return NSAttributedString(string: symbol)
        }
    }

    var activityStateViewViewModel: ActivityStateViewViewModel {
        return .init(activity: activity)
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
            if let address = cardAttributes.senderAddressValue?.truncateMiddle {
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

    var timestampFont: UIFont {
        Fonts.regular(size: 12)
    }

    var timestampColor: UIColor {
        Configuration.Color.Semantic.defaultSubtitleText
    }

    var timestamp: String {
        if let date = cardAttributes.timestampGeneralisedTimeValue?.date {
            let value = Date.formatter(with: "h:mm:ss | dd MMM yyyy").string(from: date)
            return "\(value)"
        } else {
            return ""
        }
    }

    var iconImage: TokenImagePublisher {
        tokenImageFetcher.image(token: activity.token, size: .s300)
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

    var isPendingTransaction: Bool {
        switch activity.state {
        case .completed:
            return false
        case .pending:
            return true
        case .failed:
            return false
        }
    }
}

extension TokenImageFetcher {

    public func image(token: HasTokenImage, size: GoogleContentSize) -> TokenImagePublisher {
        let name = token.symbol.nilIfEmpty ?? token.name
        let colors = [R.color.radical()!, R.color.cerulean()!, R.color.emerald()!, R.color.indigo()!, R.color.azure()!, R.color.pumpkin()!]
        let blockChainNameColor = token.server.blockChainNameColor

        return image(contractAddress: token.contractAddress,
                     server: token.server,
                     name: name,
                     type: token.type,
                     balance: token.firstNftAsset,
                     size: size,
                     contractDefinedImage: token.contractAddress.tokenImage,
                     colors: colors,
                     staticOverlayIcon: token.server.staticOverlayIcon,
                     blockChainNameColor: blockChainNameColor,
                     serverIconImage: token.server.iconImage)
    }
}
