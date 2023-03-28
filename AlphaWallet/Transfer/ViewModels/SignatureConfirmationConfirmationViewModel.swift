//
//  SignatureConfirmationConfirmationViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.02.2021.
//

import UIKit
import AlphaWalletFoundation

struct SignatureConfirmationViewModel {

    private let requester: RequesterViewModel?
    let type: ViewModelType

    init(message: SignMessageType, requester: RequesterViewModel?) {
        self.requester = requester

        switch message {
        case .eip712v3And4(let data):
            self.type = .eip712v3And4(viewModel: .init(data: data, requester: requester))
        case .message(let data):
            self.type = .message(viewModel: .init(data: data, requester: requester))
        case .personalMessage(let data):
            self.type = .personalMessage(viewModel: .init(data: data, requester: requester))
        case .typedMessage(let data):
            self.type = .typedMessage(viewModel: .init(data: data, requester: requester))
        }
    }

    var placeholderIcon: UIImage? {
        return requester == nil ? R.image.awLogoSmall() : R.image.walletConnectIcon()
    }

    var iconUrl: URL? {
        return requester?.iconUrl
    } 

    var title: String = R.string.localizable.signatureConfirmationTitle()
    var confirmationButtonTitle: String = R.string.localizable.confirmPaymentSignButtonTitle()
    var cancelationButtonTitle: String = R.string.localizable.cancel()
    var backgroundColor: UIColor = Configuration.Color.Semantic.backgroundClear
    var footerBackgroundColor: UIColor = Configuration.Color.Semantic.defaultViewBackground

    var viewModels: [SignatureConfirmationViewModel.ViewType] {
        switch type {
        case .typedMessage(let viewModel):
            return viewModel.viewModels
        case .personalMessage(let viewModel), .message(let viewModel):
            return viewModel.viewModels
        case .eip712v3And4(let viewModel):
            return viewModel.viewModels
        }
    }
}

extension SignatureConfirmationViewModel {
    
    enum ViewModelType {
        case personalMessage(viewModel: MessageConfirmationViewModel)
        case eip712v3And4(viewModel: EIP712TypedDataConfirmationViewModel)
        case typedMessage(viewModel: TypedMessageConfirmationViewModel)
        case message(viewModel: MessageConfirmationViewModel)
    }

    ///Helper enum for view model representation, when when want to display different from `TransactionConfirmationHeaderViewModel` view model
    enum ViewType {
        /// 0 - view model, 1 - should show full message button
        case headerWithShowButton(TransactionConfirmationHeaderViewModel, Bool)
        case header(TransactionConfirmationHeaderViewModel)
    }

    struct MessageConfirmationViewModel {
        private static let MessagePrefixLength = 15
        // NOTE: we are displaying short string in action scheet, whole message user will see after tapping on Show button.
        // Remove leading newspaces and new lines and get first 30 characters
        private var messagePrefix: String {
            return String(message.removingPrefixWhitespacesAndNewlines.prefix(MessageConfirmationViewModel.MessagePrefixLength))
        }
        private var availableToShowFullMessage: Bool {
            return true
        }
        private let requester: RequesterViewModel?
        let message: String

        init(data: Data, requester: RequesterViewModel?) {
            self.requester = requester
            if let value = String(data: data, encoding: .utf8) {
                message = value
            } else {
                message = data.hexEncoded
            }
        }

        var viewModels: [ViewType] {
            let header = R.string.localizable.signatureConfirmationMessageTitle()
            var values: [ViewType] = []
            values = (requester?.viewModels ?? []).compactMap { $0 as? SignatureConfirmationViewModel.ViewType }

            return values + [
                .headerWithShowButton(.init(title: .normal(messagePrefix), headerName: header, viewState: .init(section: values.count)), availableToShowFullMessage)
            ]
        }
    }

    struct EIP712TypedDataConfirmationViewModel {
        typealias EIP712TypedDataToKey = (key: String, value: EIP712TypedData.JSON)

        private let requester: RequesterViewModel?
        let values: [EIP712TypedDataToKey]

        init(data: EIP712TypedData, requester: RequesterViewModel?) {
            self.requester = requester
            var _values: [EIP712TypedDataToKey] = []
            
            if let verifyingContract = data.domainVerifyingContract, data.domainName.nonEmpty {
                _values += [(key: data.domainName, value: .string(verifyingContract.truncateMiddle)) ]
            } else if let verifyingContract = data.domainVerifyingContract {
                _values += [(key: "domain.verifyingContract", value: .string(verifyingContract.truncateMiddle)) ]
            } else if data.domainName.nonEmpty {
                _values += [(key: "domain.name", value: .string(data.domainName)) ]
            } else {
                //no-op
            }
            
            _values += data.message.keyValueRepresentationToFirstLevel
            values = _values
        }

        var viewModels: [ViewType] {
            var values: [ViewType] = []
            values = (requester?.viewModels ?? []).compactMap { $0 as? SignatureConfirmationViewModel.ViewType }

            for sectionIndex in self.values.indices {
                let data = self.values[sectionIndex]
                let string = data.value.shortStringRepresentation
                values += [
                    .headerWithShowButton(
                        .init(title: .normal(string), headerName: data.key, viewState: .init(section: Int(sectionIndex))),
                        true
                    )
                ]
            }

            return values
        }
    }

    struct TypedMessageConfirmationViewModel {
        let typedData: [EthTypedData]
        let requester: RequesterViewModel?

        init(data: [EthTypedData], requester: RequesterViewModel?) {
            self.requester = requester
            self.typedData = data
        } 

        var viewModels: [ViewType] {
            var values: [ViewType] = []
            values = (requester?.viewModels ?? []).compactMap { $0 as? SignatureConfirmationViewModel.ViewType }
            for (sectionIndex, typedMessage) in self.typedData.enumerated() {
                let string = typedMessage.value.string
                values += [
                    .headerWithShowButton(
                        .init(title: .normal(string), headerName: typedMessage.name, viewState: .init(section: Int(sectionIndex))),
                        true
                    )
                ]
            }

            return values
        }
    }
}

extension EIP712TypedData {
    var rawStringValue: NSAttributedString {
        let str = message.formattedString()
        return str
    }
}

extension EIP712TypedData.JSON {

    var keyValueRepresentationToFirstLevel: [(key: String, value: EIP712TypedData.JSON)] {
        return flatArrayRepresentation(json: self, key: nil, indention: 0, maxIndention: 1)
    }

    var shortStringRepresentation: String {
        switch self {
        case .object:
            return "{...}"
        case .string(let value):
            return value
        case .number(let value):
            return "\(value)"
        case .bool(let value):
            return "\(value)"
        case .null:
            return ""
        case .array:
            return "[...]"
        }
    }

    private func flatArrayRepresentation(json: EIP712TypedData.JSON, key: String?, indention: Int, maxIndention: Int) -> [(key: String, value: EIP712TypedData.JSON)] {
        switch json {
        case .object(let dictionary):
            if indention != maxIndention {
                return dictionary.flatMap { data -> [(key: String, value: EIP712TypedData.JSON)] in
                    return flatArrayRepresentation(json: data.value, key: data.key, indention: indention + 1, maxIndention: maxIndention)
                }
            } else if let key = key {
                return [(key: key, value: json)]
            }
        case .string, .number, .bool:
            if let key = key {
                return [(key: key, value: json)]
            }
        case .null:
            break
        case .array(let array):
            if indention != maxIndention {
                return array.flatMap {
                    flatArrayRepresentation(json: $0, key: key, indention: indention + 1, maxIndention: maxIndention)
                }
            } else if let key = key {
                return [(key: key, value: json)]
            }
        }

        return []
    }

    //TODO Better to follow the order define in the type
    func formattedString(indentationLevel: Int = 0) -> NSAttributedString {
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: Configuration.Color.Semantic.alternativeText,
            .font: Fonts.regular(size: 15)
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText,
            .font: Fonts.regular(size: 15)
        ]

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
            return NSAttributedString(string: value.description.indented(indentationLevel), attributes: valueAttributes)
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
