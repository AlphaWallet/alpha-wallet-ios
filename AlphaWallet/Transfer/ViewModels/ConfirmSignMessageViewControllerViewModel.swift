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

    var subtitle: String {
        switch message {
        case .message, .personalMessage, .typedMessage:
            return ""
        case .eip712v3And4(let message):
            let name = message.domainName
            if let verifyingContract = message.domainVerifyingContract {
                return "\(name)\n\(verifyingContract.truncateMiddle)"
            } else {
                return name
            }
        }
    }

    var subtitleFont: UIFont {
        Fonts.regular(size: 13)
    }

    var subtitleColor: UIColor {
        Colors.appText
    }

    var actionButtonTitleColor: UIColor {
        return Colors.appWhite
    }

    var actionButtonBackgroundColor: UIColor {
        return Colors.appActionButtonGreen
    }

    var actionButtonTitleFont: UIFont {
        return Fonts.regular(size: 20)
    }

    var cancelButtonTitleColor: UIColor {
        return Colors.appRed
    }

    var cancelButtonBackgroundColor: UIColor {
        return .clear
    }

    var cancelButtonTitleFont: UIFont {
        return Fonts.regular(size: 20)
    }

    var actionButtonTitle: String {
        //TODO better to be "Sign" ?
        return R.string.localizable.oK()
    }

    var cancelButtonTitle: String {
        return R.string.localizable.aWalletTokenSellConfirmCancelButtonTitle()
    }

    var singleMessageLabelFont: UIFont {
        return Fonts.semibold(size: 21)
    }

    var singleMessageLabelTextColor: UIColor {
        return Colors.darkGray
    }

    var singleMessageLabelTextAlignment: NSTextAlignment {
        switch message {
        case .message, .personalMessage, .typedMessage:
            return .center
        case .eip712v3And4:
            return .left
        }
    }

    var nameTextFont: UIFont {
        return Fonts.semibold(size: 16)
    }

    var valueTextFont: UIFont {
        return Fonts.semibold(size: 21)
    }

    var detailsBackgroundBackgroundColor: UIColor {
        return UIColor(red: 236, green: 236, blue: 236)
    }

    var singleMessageLabelText: NSAttributedString? {
        switch message {
        case .message(let data), .personalMessage(let data):
            guard let message = String(data: data, encoding: .utf8) else {
                return NSAttributedString(string: data.hexEncoded, attributes: [ .font: singleMessageLabelFont, .foregroundColor: singleMessageLabelTextColor ])
            }
            return NSAttributedString(string: message)
        case .typedMessage:
            return nil
        case .eip712v3And4(let data):
            return data.rawStringValue
        }
    }

    var typedMessagesCount: Int {
        switch message {
        case .message, .eip712v3And4, .personalMessage:
            return 0
        case .typedMessage(let typedMessage):
            return typedMessage.count
        }
    }

    private func typedMessage(at index: Int) -> EthTypedData? {
        switch message {
        case .message, .eip712v3And4, .personalMessage:
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

extension EIP712TypedData {
    var rawStringValue: NSAttributedString {
        let str = message.formattedString()
        return str
    }
}

extension EIP712TypedData.JSON {
    //TODO Better to follow the order define in the type
    func formattedString(indentationLevel: Int = 0) -> NSAttributedString {
        let nameAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: Colors.gray, .font: Fonts.light(size: 15)]
        let valueAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: R.color.dove()!, .font: Fonts.regular(size: 15)]

        switch self {
        case .object(let dictionary):
            let nextLevelIndentationString = "".indented(indentationLevel + 2)
            let indentation = NSAttributedString(string: "".indented(indentationLevel + 1))
            let str = NSMutableAttributedString(string: "{\n".indented(indentationLevel), attributes: nameAttributes)
            str.append(indentation)
            str.append(dictionary.map { key, value in
                switch value {
                case .object, .array:
                    let s = NSMutableAttributedString(string: "\(key):\n", attributes: nameAttributes)
                    s.append(value.formattedString(indentationLevel: indentationLevel + 2))
                    return s
                case .string, .number, .bool, .null:
                    let s = NSMutableAttributedString(string: "\(key): ", attributes: nameAttributes)
                    s.append(value.formattedString())
                    return s
                }
            }.joined(separator: NSAttributedString(string: ",\n\(nextLevelIndentationString)", attributes: nameAttributes)))
            str.append(NSAttributedString(string: "\n"))
            str.append(NSAttributedString(string: "}".indented(indentationLevel), attributes: nameAttributes))
            return str
        case .string(let value):
            let fittedString: String
            //Arbitrary limit to fit (some) addresses
            //TODO improve truncation. Support different device width, also depending on shape of data
            let limit = 18
            if value.count > limit {
                fittedString = "\(value.substring(to: [limit, value.count].min()!))…"
            } else {
                fittedString = value
            }
            return NSAttributedString(string: fittedString.indented(indentationLevel), attributes: valueAttributes)

        case .number(let value):
            return NSAttributedString(string: String(value).indented(indentationLevel), attributes: valueAttributes)
        case .array(let array):
            let str = NSMutableAttributedString(string: "[\n".indented(indentationLevel), attributes: nameAttributes)
            str.append(array.map { $0.formattedString(indentationLevel: indentationLevel + 1) }.joined(separator: NSAttributedString(string: ",\n", attributes: nameAttributes)))
            str.append(NSAttributedString(string: "\n"))
            str.append(NSAttributedString(string: "]".indented(indentationLevel), attributes: nameAttributes))
            return str
        case .bool(let value):
            return NSAttributedString(string: String(value).indented(indentationLevel), attributes: valueAttributes)
        case .null:
            return NSAttributedString(string: "")
        }
    }
}

private extension String {
    func indented(_ indentationLevel: Int) -> String {
        let spacesPerIndentation = 1
        let indentationPerLevel = " "
        let indentation = String(repeating: indentationPerLevel, count: spacesPerIndentation * indentationLevel)
        return "\(indentation)\(self)"
    }
}

private extension Array where Element: NSAttributedString {
    func joined(separator: NSAttributedString) -> NSAttributedString {
        var isFirst = true
        return self.reduce(NSMutableAttributedString()) { (sum, each) in
            if isFirst {
                isFirst = false
            } else {
                sum.append(separator)
            }
            sum.append(each)
            return sum
        }
    }
}