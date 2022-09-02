// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import AlphaWalletFoundation

enum SignMessageType {
    case message(Data)
    case personalMessage(Data)
    case typedMessage([EthTypedData])
    case eip712v3And4(EIP712TypedData)
}

protocol SignMessageCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: SignMessageCoordinator, didSign result: Swift.Result<Data, KeystoreError>)
    func didCancel(in coordinator: SignMessageCoordinator)
}

class SignMessageCoordinator: Coordinator {
    private let analytics: AnalyticsLogger
    private let navigationController: UINavigationController
    private let keystore: Keystore
    private let account: AlphaWallet.Address
    private var message: SignMessageType
    private let source: Analytics.SignMessageRequestSource
    private weak var signatureConfirmationDetailsViewController: SignatureConfirmationDetailsViewController?
    private var canBeDismissed = true
    private let requester: RequesterViewModel?
    private lazy var rootViewController: SignatureConfirmationViewController = {
        let controller = SignatureConfirmationViewController(viewModel: .init(message: message, requester: requester))
        controller.delegate = self
        return controller
    }()

    var coordinators: [Coordinator] = []
    weak var delegate: SignMessageCoordinatorDelegate?
    
    init(analytics: AnalyticsLogger, navigationController: UINavigationController, keystore: Keystore, account: AlphaWallet.Address, message: SignMessageType, source: Analytics.SignMessageRequestSource, requester: RequesterViewModel?) {
        self.analytics = analytics
        self.navigationController = navigationController
        self.requester = requester
        self.keystore = keystore
        self.account = account
        self.message = message
        self.source = source
    }

    private lazy var hostViewController: FloatingPanelController = {
        let panel = FloatingPanelController(isPanEnabled: false)
        panel.layout = SelfSizingPanelLayout(referenceGuide: .superview)
        panel.shouldDismissOnBackdrop = true
        panel.delegate = self
        panel.set(contentViewController: rootViewController)

        return panel
    }()

    func start() {
        analytics.log(navigation: Analytics.Navigation.signMessageRequest, properties: [
            Analytics.Properties.source.rawValue: source.rawValue,
            Analytics.Properties.messageType.rawValue: mapMessageToAnalyticsType(message).rawValue
        ])

        let presenter = UIApplication.shared.presentedViewController(or: navigationController)
        presenter.present(hostViewController, animated: true)

        rootViewController.reloadView()
    }

    private func mapMessageToAnalyticsType(_ message: SignMessageType) -> Analytics.SignMessageRequestType {
        switch message {
        case .message:
            return .message
        case .personalMessage:
            return .personalMessage
        case .typedMessage:
            return .eip712
        case .eip712v3And4:
            return .eip712v3And4
        }
    }

    func close(completion: @escaping () -> Void) {
        navigationController.dismiss(animated: true, completion: completion)
    } 

    private func signMessage(with type: SignMessageType) {
        let result: Result<Data, KeystoreError>
        switch type {
        case .message(let data):
            //This was previously `signMessage(_:for:). Changed it to `signPersonalMessage` because web3.js v1 (unlike v0.20.x) and probably other libraries expect so
            result = keystore.signPersonalMessage(data, for: account, prompt: R.string.localizable.keystoreAccessKeySign())
        case .personalMessage(let data):
            result = keystore.signPersonalMessage(data, for: account, prompt: R.string.localizable.keystoreAccessKeySign())
        case .typedMessage(let typedData):
            if typedData.isEmpty {
                result = .failure(KeystoreError.failedToSignMessage)
            } else {
                result = keystore.signTypedMessage(typedData, for: account, prompt: R.string.localizable.keystoreAccessKeySign())
            }
        case .eip712v3And4(let data):
            result = keystore.signEip712TypedData(data, for: account, prompt: R.string.localizable.keystoreAccessKeySign())
        }

        close(completion: {
            guard let delegate = self.delegate else { return }

            switch result {
            case .success(let data):
                UINotificationFeedbackGenerator.show(feedbackType: .success)

                delegate.coordinator(self, didSign: .success(data))
            case .failure(let error):
                delegate.coordinator(self, didSign: .failure(error))
            }
        })
    }
}

extension SignMessageCoordinator: FloatingPanelControllerDelegate {
    func floatingPanelDidRemove(_ fpc: FloatingPanelController) {
        delegate?.didCancel(in: self)
    }
}

extension SignMessageCoordinator: SignatureConfirmationViewControllerDelegate {

    func controller(_ controller: SignatureConfirmationViewController, continueButtonTapped sender: UIButton) {
        analytics.log(action: Analytics.Action.signMessageRequest)
        signMessage(with: message)
    }

    func controllerDidTapEdit(_ controller: SignatureConfirmationViewController, for section: Int) {
        let controller = SignatureConfirmationDetailsViewController(viewModel: controller.viewModel[section])

        let navigationController = NavigationController(rootViewController: controller)
        navigationController.makePresentationFullScreenForiOS13Migration()
        controller.navigationItem.leftBarButtonItem = .closeBarButton(self, selector: #selector(configureTransactionDidDismiss))

        hostViewController.present(navigationController, animated: true)
        signatureConfirmationDetailsViewController = controller
    }

    func didClose(in controller: SignatureConfirmationViewController) {
        analytics.log(action: Analytics.Action.cancelSignMessageRequest)
        rootViewController.dismiss(animated: true) {
            self.delegate?.didCancel(in: self)
        }
    }

    @objc func configureTransactionDidDismiss() {
        signatureConfirmationDetailsViewController?.navigationController?.dismiss(animated: true)
    }
}

private extension SignatureConfirmationViewModel {
    subscript(section: Int) -> SignatureConfirmationDetailsViewModel {
        switch self.type {
        case .message(let viewModel):
            return .init(value: .message(viewModel.message))
        case .personalMessage(let viewModel):
            return .init(value: .personalMessage(viewModel.message))
        case .typedMessage(let viewModel):
            return .init(value: .typedMessage(viewModel.typedData[section]))
        case .eip712v3And4(let viewModel):
            let value = viewModel.values[section]
            return .init(value: .eip712v3And4(key: value.key, value: value.value))
        }
    }
}
