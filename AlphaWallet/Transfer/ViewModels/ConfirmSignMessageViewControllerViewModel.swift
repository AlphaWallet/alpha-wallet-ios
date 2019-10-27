// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

//TODO make more reusable as an alert?
struct ConfirmSignMessageViewControllerViewModel {
    private let message: SignMessageType

    init(message: SignMessageType) {
        self.message = message
    }

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

	var headerTitle: String {
        return R.string.localizable.confirmSignMessage()
	}

    var actionButtonTitleColor: UIColor {
        return Colors.appWhite
    }

    var actionButtonBackgroundColor: UIColor {
        return Colors.appActionButtonGreen
    }

    var actionButtonTitleFont: UIFont {
        return Fonts.regular(size: 20)!
    }

    var cancelButtonTitleColor: UIColor {
        return Colors.appRed
    }

    var cancelButtonBackgroundColor: UIColor {
        return .clear
    }

    var cancelButtonTitleFont: UIFont {
        return Fonts.regular(size: 20)!
    }

    var actionButtonTitle: String {
        //TODO better to be "Sign" ?
        return R.string.localizable.oK()
    }

    var cancelButtonTitle: String {
        return R.string.localizable.aWalletTokenSellConfirmCancelButtonTitle()
    }

    var singleMessageLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    var singleMessageLabelTextColor: UIColor {
        return Colors.darkGray
    }

    var nameTextFont: UIFont {
        return Fonts.semibold(size: 16)!
    }

    var valueTextFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    var detailsBackgroundBackgroundColor: UIColor {
        return UIColor(red: 236, green: 236, blue: 236)
    }

    var singleMessageLabelText: String? {
        switch message {
        case .message(let data), .personalMessage(let data):
            guard let message = String(data: data, encoding: .utf8) else {
                return data.hexEncoded
            }
            return message
        case .typedMessage:
            return nil
        }
    }

    var typedMessagesCount: Int {
        switch message {
        case .message, .personalMessage:
            return 0
        case .typedMessage(let typedMessage):
            return typedMessage.count
        }
    }

    private func typedMessage(at index: Int) -> EthTypedData? {
        switch message {
        case .message, .personalMessage:
            return nil
        case .typedMessage(let typedMessage):
            if index < typedMessage.count {
                return typedMessage[index]
            } else {
                return nil
            }
        }
    }

    private func typedMessageName(at index: Int) -> String? {
        return typedMessage(at: index)?.name
    }

    private func typedMessageValue(at index: Int) -> String? {
        return typedMessage(at: index)?.value.string
    }

    func viewModelForTypedMessage(at index: Int) -> ConfirmSignMessageTableViewCellViewModel {
        return.init(
                backgroundColor: detailsBackgroundBackgroundColor,
                nameTextFont: nameTextFont,
                valueTextFont: valueTextFont,
                valueTextColor: singleMessageLabelTextColor,
                name: typedMessageName(at: index) ?? "",
                value: typedMessageValue(at: index) ?? ""
        )
    }
}
