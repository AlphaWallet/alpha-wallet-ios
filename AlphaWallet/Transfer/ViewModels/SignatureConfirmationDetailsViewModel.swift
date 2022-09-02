//
//  SignatureConfirmationDetailsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.03.2021.
//

import UIKit
import AlphaWalletFoundation

extension SignatureConfirmationDetailsViewModel {
    enum Configutation {
        case message(String)
        case personalMessage(String)
        case typedMessage(EthTypedData)
        case eip712v3And4(key: String, value: EIP712TypedData.JSON)
    }
}

enum SignatureConfirmationDetailsViewModel {
    case rawValue(viewModel: RawValueViewModel)
    case typedMessageValue(viewModel: TypedMessageViewModel)
    case eip712v3And4(viewModel: Eip712v3And4ValueViewModel)

    init(value: Configutation) {
        switch value {
        case .message, .personalMessage:
            self = .rawValue(viewModel: RawValueViewModel(rawValue: value))
        case .typedMessage(let data):
            self = .typedMessageValue(viewModel: TypedMessageViewModel(data: data))
        case .eip712v3And4(let key, let json):
            self = .eip712v3And4(viewModel: Eip712v3And4ValueViewModel(key: key, json: json))
        }
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var valueToCopy: String {
        switch self {
        case .rawValue(let viewModel):
            return viewModel.valueToCopy
        case .typedMessageValue(let viewModel):
            return viewModel.valueToCopy
        case .eip712v3And4(let viewModel):
            return viewModel.valueToCopy
        }
    }

    var title: String {
        switch self {
        case .rawValue(let viewModel):
            return viewModel.title
        case .typedMessageValue(let viewModel):
            return viewModel.title
        case .eip712v3And4:
            return String()
        }
    }
}

extension SignatureConfirmationDetailsViewModel {

    struct RawValueViewModel {
        let messageAttributedString: NSAttributedString
        var backgroundColor: UIColor = .white

        private let rawValue: Configutation

        init(rawValue: Configutation) {
            self.rawValue = rawValue

            switch rawValue {
            case .message(let message), .personalMessage(let message):
                messageAttributedString = AttributedStringProvider(rawValue: rawValue).applyAttributes(to: message)
            case .typedMessage, .eip712v3And4:
                messageAttributedString = NSAttributedString()
            }
        }

        var valueToCopy: String {
            switch rawValue {
            case .message(let message), .personalMessage(let message):
                return message
            case .typedMessage, .eip712v3And4:
                return String()
            }
        }

        var title: String {
            switch rawValue {
            case .message:
                return R.string.localizable.signatureConfirmationMessageTitle()
            case .personalMessage:
                return R.string.localizable.signatureConfirmationPersonalmessageTitle()
            case .typedMessage, .eip712v3And4:
                return String()
            }
        }

        var key: String {
            switch rawValue {
            case .message, .personalMessage, .typedMessage:
                return String()
            case .eip712v3And4(let key, _):
                return key
            }
        }
    }
}

extension SignatureConfirmationDetailsViewModel {
    struct AttributedStringProvider {

        private var singleMessageLabelFont: UIFont {
            return Fonts.semibold(size: 21)
        }

        private var singleMessageLabelTextColor: UIColor {
            return Colors.darkGray
        }

        private let textAlignment: NSTextAlignment

        init(rawValue: Configutation) {
            switch rawValue {
            case .message, .personalMessage:
                textAlignment = .center
            case .typedMessage, .eip712v3And4:
                textAlignment = .left
            }
        }

        init(textAlignment: NSTextAlignment) {
            self.textAlignment = textAlignment
        }

        func applyAttributes(to message: String) -> NSAttributedString {
            let pag = NSMutableParagraphStyle()
            pag.alignment = textAlignment

            let attributes: [NSAttributedString.Key: Any] = [
                .font: singleMessageLabelFont,
                .foregroundColor: singleMessageLabelTextColor,
                .paragraphStyle: pag
            ]

            return NSAttributedString(string: message, attributes: attributes)
        }

        func applyAttributes(to rawAttributedString: NSAttributedString) -> NSAttributedString {
            let attributedString = NSMutableAttributedString(attributedString: rawAttributedString)
            let par = NSMutableParagraphStyle()
            par.alignment = textAlignment

            attributedString.addAttribute(.paragraphStyle, value: par, range: NSRange(0 ..< attributedString.length))

            return attributedString
        }
    }
}

extension SignatureConfirmationDetailsViewModel {
    struct Eip712v3And4ValueViewModel {

        enum PresentationType {
            case complexObject(value: NSAttributedString)
            case single(value: String)
        }

        var backgroundColor: UIColor = .white
        let key: String
        var presentationType: PresentationType
        private let json: EIP712TypedData.JSON

        init(key: String, json: EIP712TypedData.JSON) {
            self.key = key
            self.json = json

            switch json {
            case .array, .object:
                let attributedString = AttributedStringProvider(textAlignment: .left).applyAttributes(to: json.formattedString())
                self.presentationType = .complexObject(value: attributedString)
            case .bool, .null, .number, .string:
                self.presentationType = .single(value: json.shortStringRepresentation)
            }
        }

        var valueToCopy: String {
            switch json {
            case .array, .object, .null:
                return String()
            case .bool(let value):
                return "\(value)"
            case .number(let value):
                return "\(value)"
            case .string(let value):
                return value
            }
        }

        var title: String {
            return String()
        }
    }
}

extension SignatureConfirmationDetailsViewModel {

    struct TypedMessageViewModel {

        var typedDataViewModel: TypedDataViewModel {
            return .init(name: data.name, value: data.value.string, isCopyAllowed: true)
        }

        private let data: EthTypedData

        init(data: EthTypedData) {
            self.data = data
        }

        var title: String {
            return data.name
        }

        var valueToCopy: String {
            return data.value.string
        }
    }
}
