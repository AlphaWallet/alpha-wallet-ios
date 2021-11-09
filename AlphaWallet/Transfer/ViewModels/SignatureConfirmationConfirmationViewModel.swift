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

    init(message: SignMessageType, walletConnectDappRequesterViewModel: WalletConnectDappRequesterViewModel?) {
        switch message {
        case .eip712v3And4(let data):
            self = .eip712v3And4(viewModel: .init(data: data, walletConnectDappRequesterViewModel: walletConnectDappRequesterViewModel))
        case .message(let data):
            self = .message(viewModel: .init(data: data, walletConnectDappRequesterViewModel: walletConnectDappRequesterViewModel))
        case .personalMessage(let data):
            self = .personalMessage(viewModel: .init(data: data, walletConnectDappRequesterViewModel: walletConnectDappRequesterViewModel))
        case .typedMessage(let data):
            self = .typedMessage(viewModel: .init(data: data, walletConnectDappRequesterViewModel: walletConnectDappRequesterViewModel))
        }
    }
    var placeholderIcon: UIImage? {
        return walletConnectDappRequesterViewModel == nil ? R.image.awLogoSmall() : R.image.walletConnectIcon()
    }

    var dappIconUrl: URL? {
        walletConnectDappRequesterViewModel?.dappIconUrl
    }

    var walletConnectDappRequesterViewModel: WalletConnectDappRequesterViewModel? {
        switch self {
        case .personalMessage(let viewModel):
            return viewModel.walletConnectDappRequesterViewModel
        case .eip712v3And4(let viewModel):
            return viewModel.walletConnectDappRequesterViewModel
        case .typedMessage(let viewModel):
            return viewModel.walletConnectDappRequesterViewModel
        case .message(let viewModel):
            return viewModel.walletConnectDappRequesterViewModel
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
        let walletConnectDappRequesterViewModel: WalletConnectDappRequesterViewModel?

        init(data: Data, walletConnectDappRequesterViewModel: WalletConnectDappRequesterViewModel?) {
            self.walletConnectDappRequesterViewModel = walletConnectDappRequesterViewModel
            if let value = String(data: data, encoding: .utf8) {
                message = value
            } else {
                message = data.hexEncoded
            }
        }

        var viewModels: [ViewModelType] {
            let header = R.string.localizable.signatureConfirmationMessageTitle()
            var values: [ViewModelType] = []
            values = WalletConnectSessionBridgeToViewModelTypeArray(walletConnectDappRequesterViewModel).convert()

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
        private let walletConnectDappRequesterViewModel: WalletConnectDappRequesterViewModel?

        init(_ walletConnectDappRequesterViewModel: WalletConnectDappRequesterViewModel?) {
            self.walletConnectDappRequesterViewModel = walletConnectDappRequesterViewModel
        }

        func convert() -> [MessageConfirmationViewModel.ViewModelType] {
            guard let viewModel = walletConnectDappRequesterViewModel else { return [] }

            var dappNameHeader: String { R.string.localizable.walletConnectDappName() }
            var dappWebsiteHeader: String { R.string.localizable.walletConnectDappWebsite() }
            var dappServerHeader: String { R.string.localizable.settingsNetworkButtonTitle() }

            return [
                .header(.init(title: .normal(viewModel.dappShortName), headerName: dappNameHeader, configuration: .init(section: 0))),
                .header(.init(title: .normal(viewModel.dappUrl.absoluteString), headerName: dappWebsiteHeader, configuration: .init(section: 0))),
                .header(.init(title: .normal(viewModel.server.name), headerName: dappServerHeader, configuration: .init(section: 0))),
            ]
        }
    }

    struct EIP712TypedDataConfirmationViewModel {
        var values: [(key: String, value: EIP712TypedData.JSON)]
        let walletConnectDappRequesterViewModel: WalletConnectDappRequesterViewModel?

        init(data: EIP712TypedData, walletConnectDappRequesterViewModel: WalletConnectDappRequesterViewModel?) {
            self.walletConnectDappRequesterViewModel = walletConnectDappRequesterViewModel
            values = [
                (key: data.domainName, value: .string(data.domainVerifyingContract?.truncateMiddle ?? ""))
            ] + data.message.keyValueRepresentationToFirstLevel
        }

        var viewModels: [MessageConfirmationViewModel.ViewModelType] {
            var values: [MessageConfirmationViewModel.ViewModelType] = []
            values = WalletConnectSessionBridgeToViewModelTypeArray(walletConnectDappRequesterViewModel).convert()

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
        let walletConnectDappRequesterViewModel: WalletConnectDappRequesterViewModel?

        init(data: [EthTypedData], walletConnectDappRequesterViewModel: WalletConnectDappRequesterViewModel?) {
            self.walletConnectDappRequesterViewModel = walletConnectDappRequesterViewModel
            self.typedData = data
        } 

        var viewModels: [MessageConfirmationViewModel.ViewModelType] {
            var values: [MessageConfirmationViewModel.ViewModelType] = []
            values = WalletConnectSessionBridgeToViewModelTypeArray(walletConnectDappRequesterViewModel).convert()
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
