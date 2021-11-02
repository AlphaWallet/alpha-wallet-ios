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

    init(message: SignMessageType, walletConnectSession: WalletConnectSessionViewModel?) {
        switch message {
        case .eip712v3And4(let data):
            self = .eip712v3And4(viewModel: .init(data: data, walletConnectSession: walletConnectSession))
        case .message(let data):
            self = .message(viewModel: .init(data: data, walletConnectSession: walletConnectSession))
        case .personalMessage(let data):
            self = .personalMessage(viewModel: .init(data: data, walletConnectSession: walletConnectSession))
        case .typedMessage(let data):
            self = .typedMessage(viewModel: .init(data: data, walletConnectSession: walletConnectSession))
        }
    }
    var placeholderIcon: UIImage? {
        return walletConnectSession == nil ? R.image.awLogoSmall() : R.image.walletConnectIcon()
    }

    var dappIconUrl: URL? {
        walletConnectSession?.dappIconUrl
    }

    var walletConnectSession: WalletConnectSessionViewModel? {
        switch self {
        case .personalMessage(let viewModel):
            return viewModel.walletConnectSession
        case .eip712v3And4(let viewModel):
            return viewModel.walletConnectSession
        case .typedMessage(let viewModel):
            return viewModel.walletConnectSession
        case .message(let viewModel):
            return viewModel.walletConnectSession
        }
    }

    var navigationTitle: String {
        return R.string.localizable.signatureConfirmationTitle()
    }

    var title: String {
        return R.string.localizable.confirmPaymentConfirmButtonTitle()
    }
    var confirmationButtonTitle: String {
        return R.string.localizable.confirmPaymentSignButtonTitle()
    }

    var cancelationButtonTitle: String {
        return R.string.localizable.cancel()
    }

    var backgroundColor: UIColor {
        return UIColor.clear
    }

    var footerBackgroundColor: UIColor {
        return Colors.appWhite
    }

    struct MessageConfirmationViewModel {
        let message: String
        private static let MessagePrefixLength = 15
        // NOTE: we are displaying short string in action scheet, whole message user will see after tapping on Show button.
        // Remove leading newspaces and new lines and get first 30 characters
        private var messagePrefix: String {
            return String(message.removingPrefixWhitespacesAndNewlines.prefix(MessageConfirmationViewModel.MessagePrefixLength))
        }
        private var availableToShowFullMessage: Bool {
            message.removingWhitespacesAndNewlines.count > messagePrefix.count
        }
        let walletConnectSession: WalletConnectSessionViewModel?

        init(data: Data, walletConnectSession: WalletConnectSessionViewModel?) {
            self.walletConnectSession = walletConnectSession
            if let value = String(data: data, encoding: .utf8) {
                message = value
            } else {
                message = data.hexEncoded
            }
        }

        var viewModels: [ViewModelType] {
            let header = R.string.localizable.signatureConfirmationMessageTitle()
            var values: [ViewModelType] = []
            values = WalletConnectSessionBridgeToViewModelTypeArray(walletConnectSession: walletConnectSession).convert()

            return values + [
                .headerWithShowButton(.init(title: .normal(messagePrefix), headerName: header, configuration: .init(section: values.count)), availableToShowFullMessage)
            ]
        }
        
        ///Helper enum for view model representation, when when want to display different from `TransactionConfirmationHeaderViewModel` view model
        enum ViewModelType {
            /// 0 - view model, 1 - should show full message button
            case headerWithShowButton(TransactionConfirmationHeaderViewModel, Bool)
            case header(TransactionConfirmationHeaderViewModel)
        }
    }

    private struct WalletConnectSessionBridgeToViewModelTypeArray {
        let walletConnectSession: WalletConnectSessionViewModel?

        func convert() -> [MessageConfirmationViewModel.ViewModelType] {
            guard let session = walletConnectSession else { return [] }

            var sessionNameHeader: String { R.string.localizable.walletConnectSessionName() }
            var serverNameHeader: String { R.string.localizable.settingsNetworkButtonTitle() }

            return [
                .header(.init(title: .normal(session.dappShortName), headerName: sessionNameHeader, configuration: .init(section: 0))),
                .header(.init(title: .normal(session.dappUrl.absoluteString), headerName: "Website", configuration: .init(section: 0))),
                .header(.init(title: .normal(session.server.name), headerName: serverNameHeader, configuration: .init(section: 0))),
            ]
        }
    }

    struct EIP712TypedDataConfirmationViewModel {
        var values: [(key: String, value: EIP712TypedData.JSON)]
        let walletConnectSession: WalletConnectSessionViewModel?

        init(data: EIP712TypedData, walletConnectSession: WalletConnectSessionViewModel?) {
            self.walletConnectSession = walletConnectSession
            values = [
                (key: data.domainName, value: .string(data.domainVerifyingContract?.truncateMiddle ?? ""))
            ] + data.message.keyValueRepresentationToFirstLevel
        }

        var viewModels: [MessageConfirmationViewModel.ViewModelType] {
            var values: [MessageConfirmationViewModel.ViewModelType] = []
            values = WalletConnectSessionBridgeToViewModelTypeArray(walletConnectSession: walletConnectSession).convert()

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
        let walletConnectSession: WalletConnectSessionViewModel?

        init(data: [EthTypedData], walletConnectSession: WalletConnectSessionViewModel?) {
            self.walletConnectSession = walletConnectSession
            self.typedData = data
        } 

        var viewModels: [MessageConfirmationViewModel.ViewModelType] {
            var values: [MessageConfirmationViewModel.ViewModelType] = []
            values = WalletConnectSessionBridgeToViewModelTypeArray(walletConnectSession: walletConnectSession).convert()
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
