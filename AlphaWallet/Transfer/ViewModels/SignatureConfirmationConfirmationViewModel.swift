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

    var navigationTitle: String = R.string.localizable.signatureConfirmationTitle()
    var confirmationButtonTitle: String = R.string.localizable.confirmPaymentSignButtonTitle()
    var cancelationButtonTitle: String = R.string.localizable.cancel()
    var backgroundColor: UIColor = UIColor.clear
    var footerBackgroundColor: UIColor = Colors.appWhite

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
            message.removingWhitespacesAndNewlines.count > messagePrefix.count
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
                .headerWithShowButton(.init(title: .normal(messagePrefix), headerName: header, configuration: .init(section: values.count)), availableToShowFullMessage)
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
                        .init(title: .normal(string), headerName: data.key, configuration: .init(section: Int(sectionIndex))),
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
                        .init(title: .normal(string), headerName: typedMessage.name, configuration: .init(section: Int(sectionIndex))),
                        true
                    )
                ]
            }

            return values
        }
    }
}
