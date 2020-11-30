//
//  SelectAssetCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit

protocol SelectAssetCoordinatorDelegate: class {
    func coordinator(_ coordinator: SelectAssetCoordinator, didSelectToken token: TokenObject)
    func selectAssetDidCancel(in coordinator: SelectAssetCoordinator)
}

class SelectAssetCoordinator: Coordinator {

    private let parentsNavigationController: UINavigationController
    private lazy var viewController = SelectAssetViewController(
        sessions: sessions,
        tokenCollection: tokenCollection,
        assetDefinitionStore: assetDefinitionStore,
        filterTokensCoordinator: filterTokensCoordinator,
        filter: filter
    )
    private let tokenCollection: TokenCollection
    private let sessions: ServerDictionary<WalletSession>
    private let filterTokensCoordinator: FilterTokensCoordinator
    private let assetDefinitionStore: AssetDefinitionStore
    private let filter: WalletFilter
    
    lazy var navigationController = UINavigationController(rootViewController: viewController)
    var coordinators: [Coordinator] = []
    weak var delegate: SelectAssetCoordinatorDelegate?

    //NOTE: `filter: WalletFilter` parameter allow us to to filter tokens we need
    init(assetDefinitionStore: AssetDefinitionStore, sessions: ServerDictionary<WalletSession>, tokenCollection: TokenCollection, navigationController: UINavigationController, filter: WalletFilter = .type([.erc20, .nativeCryptocurrency]), filterTokensCoordinator: FilterTokensCoordinator) {
        self.sessions = sessions
        self.filter = filter
        self.parentsNavigationController = navigationController
        self.tokenCollection = tokenCollection
        self.assetDefinitionStore = assetDefinitionStore
        self.filterTokensCoordinator = filterTokensCoordinator
        self.navigationController.hidesBottomBarWhenPushed = true
        viewController.delegate = self
    }

    func start() {
        navigationController.makePresentationFullScreenForiOS13Migration()
        parentsNavigationController.present(navigationController, animated: true)
    }
}

extension SelectAssetCoordinator: SelectAssetViewControllerDelegate {

    func controller(_ controller: SelectAssetViewController, didSelectToken token: TokenObject) {
        //NOTE: for now we dismiss assets vc because then we will not able to close it, after payment flow.
        //first needs to update payment flow, make it push to navigation stack
        navigationController.dismiss(animated: true) {
            self.delegate?.coordinator(self, didSelectToken: token)
        }
    }

    func controller(_ controller: SelectAssetViewController, didCancelSelected sender: UIBarButtonItem) {
        navigationController.dismiss(animated: true) {
            self.delegate?.selectAssetDidCancel(in: self)
        }
    }
}
