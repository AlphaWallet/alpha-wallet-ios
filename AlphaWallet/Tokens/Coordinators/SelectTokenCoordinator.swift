//
//  SelectTokenCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit

protocol SelectTokenCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: SelectTokenCoordinator, didSelectToken token: Token)
    func didCancel(in coordinator: SelectTokenCoordinator)
}

struct TokenTypeFilter: TokenFilterProtocol {
    let tokenTypes: [TokenType]

    func filter(token: Token) -> Bool {
        tokenTypes.contains(token.type)
    }
}

struct NativeCryptoOrErc20TokenFilter: TokenFilterProtocol {
    func filter(token: Token) -> Bool {
        TokenTypeFilter(tokenTypes: [.erc20, .nativeCryptocurrency])
            .filter(token: token)
    }
}

class SelectTokenCoordinator: Coordinator {

    private let parentsNavigationController: UINavigationController
    private (set) lazy var rootViewController: SelectTokenViewController = {
        let viewModel = SelectTokenViewModel(wallet: wallet, tokenBalanceService: tokenBalanceService, tokenCollection: tokenCollection, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, filter: filter)
        let viewController = SelectTokenViewController(viewModel: viewModel)
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem.closeBarButton(self, selector: #selector(closeDidSelect))

        return viewController
    }()

    private let tokenCollection: TokenCollection
    private let assetDefinitionStore: AssetDefinitionStore
    private let filter: WalletFilter
    private let eventsDataStore: NonActivityEventsDataStore
    private let wallet: Wallet
    private let tokenBalanceService: TokenBalanceService

    lazy var navigationController = UINavigationController(rootViewController: rootViewController)
    var coordinators: [Coordinator] = []
    weak var delegate: SelectTokenCoordinatorDelegate?

    //NOTE: `filter: WalletFilter` parameter allow us to to filter tokens we need
    init(assetDefinitionStore: AssetDefinitionStore, wallet: Wallet, tokenBalanceService: TokenBalanceService, tokenCollection: TokenCollection, navigationController: UINavigationController, filter: WalletFilter, eventsDataStore: NonActivityEventsDataStore) {
        self.eventsDataStore = eventsDataStore
        self.wallet = wallet
        self.tokenBalanceService = tokenBalanceService
        self.filter = filter
        self.parentsNavigationController = navigationController
        self.tokenCollection = tokenCollection
        self.assetDefinitionStore = assetDefinitionStore
        self.navigationController.hidesBottomBarWhenPushed = true

        rootViewController.delegate = self
    }

    func configureForSelectionSwapToken() {
        rootViewController.headerView.isHidden = false
        rootViewController.navigationItem.rightBarButtonItem = nil
        rootViewController.navigationItem.title = nil
        rootViewController.headerView.closeButton.addTarget(self, action: #selector(closeDidSelect), for: .touchUpInside)
    }

    func start() {
        navigationController.makePresentationFullScreenForiOS13Migration()
        parentsNavigationController.present(navigationController, animated: true)
    } 

    @objc private func closeDidSelect(_ sender: UIBarButtonItem) {
        close()
    }

    func close() {
        if let navigationController = rootViewController.navigationController {
            navigationController.dismiss(animated: true) {
                self.delegate?.didCancel(in: self)
            }
        } else {
            rootViewController.dismiss(animated: true) {
                self.delegate?.didCancel(in: self)
            }
        }
    }
}

extension SelectTokenCoordinator: SelectTokenViewControllerDelegate {

    func controller(_ controller: SelectTokenViewController, didSelectToken token: Token) {
        //NOTE: for now we dismiss assets vc because then we will not able to close it, after payment flow.
        //first needs to update payment flow, make it push to navigation stack
        if let navigationController = rootViewController.navigationController {
            navigationController.dismiss(animated: true) {
                self.delegate?.coordinator(self, didSelectToken: token)
            }
        } else {
            rootViewController.dismiss(animated: true) {
                self.delegate?.coordinator(self, didSelectToken: token)
            }
        }
    }
}
