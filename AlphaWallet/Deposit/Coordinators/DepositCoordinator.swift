// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import UIKit

protocol DepositCoordinatorDelegate: class, CanOpenURL {
}

class DepositCoordinator: Coordinator {

    let navigationController: UINavigationController
    let account: Wallet
    var coordinators: [Coordinator] = []
    weak var delegate: DepositCoordinatorDelegate?

    init(
        navigationController: UINavigationController,
        account: Wallet,
        delegate: DepositCoordinatorDelegate?
    ) {
        self.navigationController = navigationController
        self.account = account
        self.delegate = delegate
    }

    func start(from barButtonItem: UIBarButtonItem? = .none) {
        showAlertSheet(from: barButtonItem)
    }

    func start(from view: UIView) {
        let alertController = makeAlertSheet()
        alertController.popoverPresentationController?.sourceView = view
        alertController.popoverPresentationController?.sourceRect = view.centerRect
        navigationController.present(alertController, animated: true, completion: nil)
    }

    private func makeAlertSheet() -> UIAlertController {
        let alertController = UIAlertController(
            title: nil,
            message: R.string.localizable.depositBuyLabelTitle(),
            preferredStyle: .actionSheet
        )
        let coinbaseAction = UIAlertAction(title: R.string.localizable.depositBuyButtonCoinbaseTitle(), style: .default) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.showCoinbase()
        }
        let shapeShiftAction = UIAlertAction(title: R.string.localizable.depositBuyButtonShapeShiftTitle(), style: .default) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.showShapeShift()
        }
        let changellyAction = UIAlertAction(title: R.string.localizable.depositBuyButtonChangellyTitle(), style: .default) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.showChangelly()
        }
        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in }

        alertController.addAction(coinbaseAction)
        alertController.addAction(shapeShiftAction)
        alertController.addAction(changellyAction)
        alertController.addAction(cancelAction)
        return alertController
    }

    func showAlertSheet(from barButtonItem: UIBarButtonItem? = .none) {
        let alertController = makeAlertSheet()
        alertController.popoverPresentationController?.barButtonItem = barButtonItem
        navigationController.present(alertController, animated: true, completion: nil)
    }

    func showCoinbase() {
        let widget = CoinbaseBuyWidget(
            address: account.address.description
        )
        delegate?.didPressOpenWebPage(widget.url, in: navigationController)
    }

    func showShapeShift() {
        let widget = ShapeShiftBuyWidget(
            address: account.address.description
        )
        delegate?.didPressOpenWebPage(widget.url, in: navigationController)
    }

    func showChangelly() {
        let widget = ChangellyBuyWidget(
            address: account.address.description
        )
        delegate?.didPressOpenWebPage(widget.url, in: navigationController)
    }
}
