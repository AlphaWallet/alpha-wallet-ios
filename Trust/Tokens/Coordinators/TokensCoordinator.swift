// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol TokensCoordinatorDelegate: class {
    func didPress(for type: PaymentFlow, in coordinator: TokensCoordinator)
    func didPressStormBird(for type: PaymentFlow, token: TokenObject, in coordinator: TokensCoordinator)
}

class TokensCoordinator: Coordinator {

    let navigationController: UINavigationController
    let session: WalletSession
    let keystore: Keystore
    var coordinators: [Coordinator] = []
    let storage: TokensDataStore

    lazy var tokensViewController: TokensViewController = {
        let controller = TokensViewController(
            account: session.account,
            dataStore: storage
        )
        controller.delegate = self
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(edit))
        controller.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addToken))
        return controller
    }()
    weak var delegate: TokensCoordinatorDelegate?

    lazy var rootViewController: TokensViewController = {
        return self.tokensViewController
    }()

    init(
        navigationController: UINavigationController = NavigationController(),
        session: WalletSession,
        keystore: Keystore,
        tokensStorage: TokensDataStore
    ) {
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.session = session
        self.keystore = keystore
        self.storage = tokensStorage
    }

    func start() {
        showTokens()
    }

    func showTokens() {
        navigationController.viewControllers = [rootViewController]
    }

    func newTokenViewController() -> NewTokenViewController {
        let controller = NewTokenViewController()
        controller.delegate = self
        return controller
    }

    @objc func addToken() {
        let controller = newTokenViewController()
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismiss))
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .formSheet
        navigationController.present(nav, animated: true, completion: nil)
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true, completion: nil)
    }

    @objc func edit() {
        let controller = EditTokensViewController(
            session: session,
            storage: storage
        )
        navigationController.pushViewController(controller, animated: true)
    }
}

extension TokensCoordinator: TokensViewControllerDelegate {
    func didSelect(token: TokenObject, in viewController: UIViewController) {

        let type: TokenType = {
            if token.isStormBird {
                return .stormBird
            }
            return TokensDataStore.etherToken(for: session.config) == token ? .ether : .token
        }()

        switch type {
        case .ether:
            delegate?.didPress(for: .send(type: .ether(destination: .none)), in: self)
        case .token:
            delegate?.didPress(for: .send(type: .token(token)), in: self)
        case .stormBird:
            delegate?.didPressStormBird(for: .send(type: .stormBird(token)), token: token, in: self)
        }
    }

    func didDelete(token: TokenObject, in viewController: UIViewController) {
        storage.delete(tokens: [token])
        tokensViewController.fetch()
    }

    func didPressAddToken(in viewController: UIViewController) {
        addToken()
    }
    private func getContractBalance(for address: String,
                                    in viewController: NewTokenViewController) {
        storage.getContractBalance(for: address) { result in
            switch result {
            case .success(let balance):
                viewController.updateBalanceValue(balance)
                NSLog("Balance:  \(balance)")
            case .failure: break
            }
        }
    }

    private func getDecimals(for address: String,
                             in viewController: NewTokenViewController) {
        storage.getDecimals(for: address) { result in
            switch result {
            case .success(let decimal):
                viewController.updateDecimalsValue(decimal)
                NSLog("Decimal:  \(decimal)")
            case .failure: break
            }
        }
    }

}

extension TokensCoordinator: NewTokenViewControllerDelegate {
    func didAddToken(token: ERC20Token, in viewController: NewTokenViewController) {
        storage.addCustom(token: token)
        tokensViewController.fetch()
        dismiss()
    }

    // TODO: Clean this up
    func didAddAddress(address: String, in viewController: NewTokenViewController) {
        storage.getContractName(for: address) { result in
            switch result {
            case .success(let name):
                viewController.updateNameValue(name)
                NSLog("Name:  \(name)")
            case .failure: break
            }
        }

        storage.getContractSymbol(for: address) { result in
            switch result {
            case .success(let symbol):
                viewController.updateSymbolValue(symbol)
                NSLog("Symbol:  \(symbol)")
            case .failure: break
            }
        }

        storage.getIsECR875(for: address) { result in
            switch result {
            case .success(let isStormBird):
                viewController.updateFormForStormBirdToken(isStormBird)
                if isStormBird {
                    self.getContractBalance(for: address, in: viewController)
                } else {
                    self.getDecimals(for: address, in: viewController)
                }
                NSLog("isStormBird:  \(isStormBird)")
            case .failure:
                self.getDecimals(for: address, in: viewController)
            }
        }
    }
}
