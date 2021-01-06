// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import CryptoSwift
import Result

enum SignMessageType {
    case message(Data)
    case personalMessage(Data)
    case typedMessage([EthTypedData])
    case eip712v3(EIP712TypedData)
}

protocol SignMessageCoordinatorDelegate: class {
    func didCancel(in coordinator: SignMessageCoordinator)
}

class SignMessageCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let keystore: Keystore
    private let account: AlphaWallet.Address
    private var message: SignMessageType?

    var coordinators: [Coordinator] = []
    weak var delegate: SignMessageCoordinatorDelegate?
    var didComplete: ((Result<Data, AnyError>) -> Void)?

    init(
        navigationController: UINavigationController,
        keystore: Keystore,
        account: AlphaWallet.Address
    ) {
        self.navigationController = navigationController
        self.keystore = keystore
        self.account = account
    }

    func start(with message: SignMessageType) {
        self.message = message
        let alertController = makeAlertController(with: message)
        navigationController.present(alertController, animated: true, completion: nil)
    }

    private func makeAlertController(with type: SignMessageType) -> UIViewController {
        let vc = ConfirmSignMessageViewController()
        vc.delegate = self
        vc.configure(viewModel: .init(message: type))
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        return vc
    }

    private func handleSignedMessage(with type: SignMessageType) {
        let result: Result<Data, KeystoreError>
        switch type {
        case .message(let data):
            result = keystore.signMessage(data, for: account)
        case .personalMessage(let data):
            result = keystore.signPersonalMessage(data, for: account)
        case .typedMessage(let typedData):
            if typedData.isEmpty {
                result = .failure(KeystoreError.failedToSignMessage)
            } else {
                result = keystore.signTypedMessage(typedData, for: account)
            }
        case .eip712v3(let data):
            result = keystore.signEip712TypedData(data, for: account)
        }
        switch result {
        case .success(let data):
            showFeedback()
            didComplete?(.success(data))
        case .failure(let error):
            navigationController.displaySuccess(message: error.errorDescription)
            didComplete?(.failure(AnyError(error)))
        }
    }

    private func showFeedback() {
        UINotificationFeedbackGenerator.show(feedbackType: .success)
    }
}

extension SignMessageCoordinator: ConfirmSignMessageViewControllerDelegate {
    func didPressProceed(in viewController: ConfirmSignMessageViewController) {
        navigationController.dismiss(animated: true)
        guard let message = message else { return }
        handleSignedMessage(with: message)
    }

    func didPressCancel(in viewController: ConfirmSignMessageViewController) {
        navigationController.dismiss(animated: true)
        didComplete?(.failure(AnyError(DAppError.cancelled)))
        delegate?.didCancel(in: self)
    }
}
