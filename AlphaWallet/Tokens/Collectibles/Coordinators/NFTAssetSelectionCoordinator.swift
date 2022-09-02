//
//  NFTAssetSelectionCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit
import AlphaWalletFoundation

protocol NFTAssetSelectionCoordinatorDelegate: AnyObject {
    func didFinish(in coordinator: NFTAssetSelectionCoordinator)
    func didTapSend(in coordinator: NFTAssetSelectionCoordinator, token: Token, tokenHolders: [TokenHolder])
}

class NFTAssetSelectionCoordinator: Coordinator {

    private let parentsNavigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: NFTAssetSelectionCoordinatorDelegate?
    private let token: Token
    private let tokenHolders: [TokenHolder]
    private let tokenCardViewFactory: TokenCardViewFactory

    //NOTE: `filter: WalletFilter` parameter allow us to filter tokens we needed
    init(navigationController: UINavigationController, token: Token, tokenHolders: [TokenHolder], tokenCardViewFactory: TokenCardViewFactory) {
        self.token = token
        self.tokenHolders = tokenHolders
        self.parentsNavigationController = navigationController
        self.tokenCardViewFactory = tokenCardViewFactory
    }

    func start() {
        let viewController = NFTAssetSelectionViewController(viewModel: .init(token: token, tokenHolders: tokenHolders), tokenCardViewFactory: tokenCardViewFactory)
        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonSelected))
        viewController.delegate = self
        let navigationController = NavigationController(rootViewController: viewController)
        navigationController.makePresentationFullScreenForiOS13Migration()
        navigationController.hidesBottomBarWhenPushed = true

        parentsNavigationController.present(navigationController, animated: true)
    }

    @objc private func doneButtonSelected(_ sender: UIBarButtonItem) {
        parentsNavigationController.dismiss(animated: true) {
            self.delegate?.didFinish(in: self)
        }
    }
}

extension NFTAssetSelectionCoordinator: NFTAssetSelectionViewControllerDelegate {

    func didTapSend(in viewController: NFTAssetSelectionViewController, token: Token, tokenHolders: [TokenHolder]) {
        parentsNavigationController.dismiss(animated: true) {
            self.delegate?.didTapSend(in: self, token: token, tokenHolders: tokenHolders)
        }
    }
}
