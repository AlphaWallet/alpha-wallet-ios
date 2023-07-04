//
//  ChangeCurrencyCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.06.2020.
//

import UIKit
import AlphaWalletFoundation

protocol ChangeCurrencyCoordinatorDelegate: AnyObject {
    func didChangeCurrency(in coordinator: ChangeCurrencyCoordinator, currency: AlphaWalletFoundation.Currency)
    func didClose(in coordinator: ChangeCurrencyCoordinator)
}

class ChangeCurrencyCoordinator: NSObject, Coordinator {

    private let navigationController: UINavigationController
    private let currencyService: CurrencyService
    private lazy var viewController: ChangeCurrencyViewController = {
        let viewModel = ChangeCurrencyViewModel(currencyService: currencyService)
        let viewController = ChangeCurrencyViewController(viewModel: viewModel)
        viewController.delegate = self

        return viewController
    }()

    var coordinators: [Coordinator] = []
    weak var delegate: ChangeCurrencyCoordinatorDelegate?

    init(navigationController: UINavigationController, currencyService: CurrencyService) {
        self.currencyService = currencyService
        self.navigationController = navigationController
        super.init()
    }

    func start() {
        navigationController.pushViewController(viewController, animated: true)
    }

}

extension ChangeCurrencyCoordinator: ChangeCurrencyViewControllerDelegate {
    func controller(_ viewController: ChangeCurrencyViewController, didSelectCurrency currency: AlphaWalletFoundation.Currency) {
        delegate?.didChangeCurrency(in: self, currency: currency)
    }

    func didClose(in viewController: ChangeCurrencyViewController) {
        delegate?.didClose(in: self)
    }
}
