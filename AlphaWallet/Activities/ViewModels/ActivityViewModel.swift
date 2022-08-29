// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import AlphaWalletFoundation
import UIKit

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
        R.color.dove()!
    }

    var subTitleFont: UIFont {
        Fonts.regular(size: 12)
    }

    var timestampFont: UIFont {
        Fonts.regular(size: 12)
    }

    var timestampColor: UIColor {
        R.color.dove()!
    }

    var timestamp: String {
        if let date = cardAttributes.timestampGeneralisedTimeValue?.date {
            let value = Date.formatter(with: "h:mm:ss | dd MMM yyyy").string(from: date)
            return "\(value)"
        } else {
            return ""
        }
    }

    var iconImage: Subscribable<TokenImage> {
        activity.token.icon(withSize: .s300)
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

extension HasTokenImage {

    public func icon(withSize size: GoogleContentSize) -> Subscribable<TokenImage> {
        let name = symbol.nilIfEmpty ?? name
        let colors = [R.color.radical()!, R.color.cerulean()!, R.color.emerald()!, R.color.indigo()!, R.color.azure()!, R.color.pumpkin()!]
        let blockChainNameColor = server.blockChainNameColor
        return TokenImageFetcher.instance.image(contractAddress: contractAddress, server: server, name: name, type: type, balance: firstNftAsset, size: size, contractDefinedImage: contractAddress.tokenImage, colors: colors, staticOverlayIcon: server.staticOverlayIcon, blockChainNameColor: blockChainNameColor, serverIconImage: server.iconImage)
    }
}
