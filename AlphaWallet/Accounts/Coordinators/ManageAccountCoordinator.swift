// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol ManageAccountCoordinatorDelegate: class {
    func coordinator(_ coordinator: ManageAccountCoordinator, didSelectOption option: ManageAccountOption, in wallet: Wallet)
}

class ManageAccountCoordinator: Coordinator {
    
    var coordinators: [Coordinator] = []
    
    lazy var viewController: ManageAccountViewController = {
        let contoller = ManageAccountViewController(viewModel: viewModel, balanceCoordinator: balanceCoordinator)
        contoller.delegate = self
        return contoller
    }()
    
    private let viewModel: ManageAccountViewModel
    private let balanceCoordinator: GetNativeCryptoCurrencyBalanceCoordinator
    let navigationController: UINavigationController
    weak var delegate: ManageAccountCoordinatorDelegate?
    private let wallet: Wallet
    
    init(wallet: Wallet, balance: Balance?, balanceCoordinator: GetNativeCryptoCurrencyBalanceCoordinator, navigationController: UINavigationController, keystore: Keystore) {
        
        self.wallet = wallet
        self.balanceCoordinator = balanceCoordinator
        self.navigationController = navigationController
        viewModel = ManageAccountViewModel(wallet: wallet, balance: balance, keystore: keystore)
    }
    
    func start() {
        navigationController.pushViewController(viewController, animated: true)
    }
}

extension ManageAccountCoordinator : ManageAccountViewControllerDelegate {
    
    func controller(_ controller: ManageAccountViewController, didSelectOption option: ManageAccountOption) {
        delegate?.coordinator(self, didSelectOption: option, in: wallet)
    }
}
