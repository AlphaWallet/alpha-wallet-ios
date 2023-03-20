// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import AlphaWalletFoundation

protocol SignMessageCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: SignMessageCoordinator, didSign result: Data)
    func didCancel(in coordinator: SignMessageCoordinator)
}

extension SignMessageValidatorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return R.string.localizable.signMessageValidationEmptyMessage()
        case .notMatchesToChainId(let active, let requested, let source):
            switch source {
            case .dappBrowser, .deepLink, .tokenScript:
                return R.string.localizable.signMessageValidationDappBrowserRequestedChainUnavailable(active.name, requested.name)
            case .walletConnect:
                return R.string.localizable.signMessageValidationWalletConnectV1RequestedChainUnavailable(active.name, requested.name)
            }
        case .notMatchesToAnyOfChainIds(_, let requested, _):
            return R.string.localizable.signMessageValidationWalletConnectV2RequestedChainUnavailable(requested.name, requested.name)
        }

    }
}

class SignMessageCoordinator: Coordinator {
    private let analytics: AnalyticsLogger
    private let navigationController: UINavigationController
    private let keystore: Keystore
    private let account: AlphaWallet.Address
    private let message: SignMessageType
    private let source: Analytics.SignMessageRequestSource
    private weak var signatureConfirmationDetailsViewController: SignatureConfirmationDetailsViewController?
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
            Analytics.Properties.source.rawValue: source.description,
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

    private func sign(message: SignMessageType) async throws -> Data {
        switch message {
        case .message(let data):
            //This was previously `signMessage(_:for:). Changed it to `signPersonalMessage` because web3.js v1 (unlike v0.20.x) and probably other libraries expect so
            return try await keystore.signPersonalMessage(data, for: account, prompt: R.string.localizable.keystoreAccessKeySign()).get()
        case .personalMessage(let data):
            return try await keystore.signPersonalMessage(data, for: account, prompt: R.string.localizable.keystoreAccessKeySign()).get()
        case .typedMessage(let typedData):
            return try await keystore.signTypedMessage(typedData, for: account, prompt: R.string.localizable.keystoreAccessKeySign()).get()
        case .eip712v3And4(let data):
            return try await keystore.signEip712TypedData(data, for: account, prompt: R.string.localizable.keystoreAccessKeySign()).get()
        }
    }

    private func showError(error: Error) {
        UIApplication.shared
            .presentedViewController(or: navigationController)
            .displayError(message: error.localizedDescription)
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

        Task { @MainActor in
            do {
                let data = try await sign(message: message)

                close(completion: {
                    UINotificationFeedbackGenerator.show(feedbackType: .success)

                    self.delegate?.coordinator(self, didSign: data)
                })
            } catch {
                showError(error: error)
            }
        }
    }

    func controllerDidTapEdit(_ controller: SignatureConfirmationViewController, for section: Int) {
        let controller = SignatureConfirmationDetailsViewController(viewModel: controller.viewModel[section])

        let navigationController = NavigationController(rootViewController: controller)
        navigationController.makePresentationFullScreenForiOS13Migration()
        controller.navigationItem.rightBarButtonItem = .closeBarButton(self, selector: #selector(configureTransactionDidDismiss))

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
