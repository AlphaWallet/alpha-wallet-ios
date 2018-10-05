// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import TrustKeystore
import CryptoSwift
import Result

enum SignMesageType {
    case message(Data)
    case personalMessage(Data)
    case typedMessage([EthTypedData])
}

protocol SignMessageCoordinatorDelegate: class {
    func didCancel(in coordinator: SignMessageCoordinator)
}

class SignMessageCoordinator: Coordinator {
    private let navigationController: UINavigationController
    public let keystore: Keystore
    private let account: Account

    var coordinators: [Coordinator] = []
    weak var delegate: SignMessageCoordinatorDelegate?
    var didComplete: ((Result<Data, AnyError>) -> Void)?

    init(
        navigationController: UINavigationController,
        keystore: Keystore,
        account: Account
    ) {
        self.navigationController = navigationController
        self.keystore = keystore
        self.account = account
    }

    func start(with type: SignMesageType) {
        let alertController = makeAlertController(with: type)
        navigationController.present(alertController, animated: true, completion: nil)
    }

    private func makeAlertController(with type: SignMesageType) -> UIAlertController {
        let alertController = UIAlertController(
            title: R.string.localizable.confirmSignMessage(),
            message: message(for: type),
            preferredStyle: .alert
        )
        let signAction = UIAlertAction(
            title: R.string.localizable.oK(),
            style: .default
        ) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.handleSignedMessage(with: type)
        }
        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.didComplete?(.failure(AnyError(DAppError.cancelled)))
            strongSelf.delegate?.didCancel(in: strongSelf)
        }
        alertController.addAction(signAction)
        alertController.addAction(cancelAction)
        return alertController
    }

    func message(for type: SignMesageType) -> String {
        switch type {
        case .message(let data):
            return data.hexEncoded
        case .personalMessage(let data):
            return String(data: data, encoding: .utf8)!
        case .typedMessage(let (typedData)):
            let string = typedData.map {
                return "\($0.name) : \($0.value.string)"
            }.joined(separator: "\n")
            return string
        }
    }

    func isMessage(data: Data) -> Bool {
        guard let _ = String(data: data, encoding: .utf8) else { return false }
        return true
    }

    private func handleSignedMessage(with type: SignMesageType) {
        let result: Result<Data, KeystoreError>
        switch type {
        case .message(let data):
            if isMessage(data: data) {
                result = keystore.signMessage(data, for: account)
            } else {
                result = keystore.signHash(data, for: account)
            }
        case .personalMessage(let data):
            result = keystore.signPersonalMessage(data, for: account)
        case .typedMessage(let typedData):
            if typedData.isEmpty {
                result = .failure(KeystoreError.failedToSignMessage)
            } else {
                result = keystore.signTypedMessage(typedData, for: account)
            }
        }
        switch result {
        case .success(let data):
            didComplete?(.success(data))
        case .failure(let error):
            didComplete?(.failure(AnyError(error)))
        }
    }
}
