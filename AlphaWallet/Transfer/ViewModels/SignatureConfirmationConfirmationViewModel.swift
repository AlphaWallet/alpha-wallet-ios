//
//  SignatureConfirmationConfirmationViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.02.2021.
//

import UIKit

enum SignatureConfirmationViewModel {
    case personalMessage(viewModel: MessageConfirmationViewModel)
    case eip712v3And4(viewModel: EIP712TypedDataConfirmationViewModel)
    case typedMessage(viewModel: TypedMessageConfirmationViewModel)
    case message(viewModel: MessageConfirmationViewModel)

    init(message: SignMessageType) {
        switch message {
        case .eip712v3And4(let data):
            self = .eip712v3And4(viewModel: .init(data: data))
        case .message(let data):
            self = .message(viewModel: .init(data: data))
        case .personalMessage(let data):
            self = .personalMessage(viewModel: .init(data: data))
        case .typedMessage(let data):
            self = .typedMessage(viewModel: .init(data: data))
        }
    }

    var navigationTitle: String {
        return R.string.localizable.signatureConfirmationTitle()
    }

    var title: String {
        return R.string.localizable.confirmPaymentConfirmButtonTitle()
    }
    var confirmationButtonTitle: String {
        return R.string.localizable.confirmPaymentConfirmButtonTitle()
    }

    var rejectionButtonTitle: String {
        return R.string.localizable.confirmPaymentRejectButtonTitle()
    }

    var backgroundColor: UIColor {
        return UIColor.clear
    }

    var footerBackgroundColor: UIColor {
        return R.color.white()!
    }

    struct MessageConfirmationViewModel {
        let message: String
        private static let MessagePrefixLength = 15
        //NOTE: we are displaying short string in action scheet, whole message user will see after tapping on Show button.
        //Remove leading newspaces and new lines and get first 30 characters
        private var messagePrefix: String {
            return String(message.removingPrefixWhitespacesAndNewlines.prefix(MessageConfirmationViewModel.MessagePrefixLength))
        }
        var availableToShowFullMessage: Bool {
            message.removingWhitespacesAndNewlines.count > messagePrefix.count
        }
        
        init(data: Data) {
            if let value = String(data: data, encoding: .utf8) {
                message = value
            } else {
                message = data.hexEncoded
            }
        } 

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let header = R.string.localizable.signatureConfirmationMessageTitle()
            return .init(title: .normal(messagePrefix), headerName: header, configuration: .init(section: section))
        } 
    }

    struct EIP712TypedDataConfirmationViewModel {
        var values: [(key: String, value: EIP712TypedData.JSON)]

        init(data: EIP712TypedData) {
            values = [
                (key: data.domainName, value: .string(data.domainVerifyingContract?.truncateMiddle ?? ""))
            ] + data.message.keyValueRepresentationToFirstLevel
        }

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let data = values[section]
            return .init(title: .normal(data.value.shortStringRepresentation), headerName: data.key, configuration: .init(section: section))
        }
    }

    struct TypedMessageConfirmationViewModel {
        let typedData: [EthTypedData]

        init(data: [EthTypedData]) {
            self.typedData = data
        }

        func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
            let typedMessage = typedData[section]
            return .init(title: .normal(typedMessage.value.string), headerName: typedMessage.name, configuration: .init(section: section))
        }
    }
}

extension String {
    var removingPrefixWhitespacesAndNewlines: String {
        guard let index = firstIndex(where: { !CharacterSet(charactersIn: String($0)).isSubset(of: .whitespacesAndNewlines) }) else {
            return self
        }
        return String(self[index...])
    }

    var removingWhitespacesAndNewlines: String {
        let value = components(separatedBy: .whitespacesAndNewlines)
        return value.joined()
    }
}
