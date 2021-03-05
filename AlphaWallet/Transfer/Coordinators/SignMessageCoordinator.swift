// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import CryptoSwift
import Result 

enum SignMessageType {
    case message(Data)
    case personalMessage(Data)
    case typedMessage([EthTypedData])
    case eip712v3And4(EIP712TypedData)
}

protocol SignMessageCoordinatorDelegate: class {
    func coordinator(_ coordinator: SignMessageCoordinator, didSign result: ResultResult<Data, KeystoreError>.t)
    func didCancel(in coordinator: SignMessageCoordinator)
}

class SignMessageCoordinator: Coordinator {
    private let presentationNavigationController: UINavigationController
    private let keystore: Keystore
    private let account: AlphaWallet.Address
    private var message: SignMessageType

    var coordinators: [Coordinator] = []
    weak var delegate: SignMessageCoordinatorDelegate?

    private lazy var confirmationViewController: SignatureConfirmationViewController = {
        let controller = SignatureConfirmationViewController(viewModel: .init(message: message))
        controller.delegate = self
        return controller
    }()

    private lazy var navigationController: UINavigationController = {
        let controller = UINavigationController(rootViewController: confirmationViewController)
        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve
        controller.view.backgroundColor = UIColor.black.withAlphaComponent(0.6)

        return controller
    }()

    init(navigationController: UINavigationController, keystore: Keystore, account: AlphaWallet.Address, message: SignMessageType) {
        self.presentationNavigationController = navigationController
        self.keystore = keystore
        self.account = account
        self.message = message
    }

    func start() {
        guard let keyWindow = UIApplication.shared.keyWindow else { return }

        if let controller = keyWindow.rootViewController?.presentedViewController {
            controller.present(navigationController, animated: false)
        } else {
            presentationNavigationController.present(navigationController, animated: false)
        }

        confirmationViewController.reloadView()
    }

    func dissmissAnimated(completion: @escaping () -> Void) {
        confirmationViewController.dismissViewAnimated {
            //Needs a strong self reference otherwise `self` might have been removed by its owner by the time animation completes and the `completion` block not called
            self.navigationController.dismiss(animated: true, completion: completion)
        }
    }

    private func signMessage(with type: SignMessageType) {
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
        case .eip712v3And4(let data):
            result = keystore.signEip712TypedData(data, for: account)
        }

        dissmissAnimated(completion: {
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

extension SignMessageCoordinator: SignatureConfirmationViewControllerDelegate {

    func controller(_ controller: SignatureConfirmationViewController, continueButtonTapped sender: UIButton) {
        signMessage(with: message)
    }

    func controllerDidTapEdit(_ controller: SignatureConfirmationViewController, for section: Int) {
        let controller = SignatureConfirmationDetailsViewController(viewModel: controller.viewModel[section])

        navigationController.pushViewController(controller, animated: true)
    }

    func didClose(in controller: SignatureConfirmationViewController) {
        navigationController.dismiss(animated: false) {
            guard let delegate = self.delegate else { return }
            delegate.didCancel(in: self)
        }
    }
}

private extension SignatureConfirmationViewModel {
    subscript(section: Int) -> SignatureConfirmationDetailsViewModel {
        switch self {
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
