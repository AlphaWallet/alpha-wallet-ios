// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import UIKit

class DepositCoordinator: Coordinator {

    let navigationController: UINavigationController
    let account: Wallet
    var coordinators: [Coordinator] = []

    init(
        navigationController: UINavigationController,
        account: Wallet
    ) {
        self.navigationController = navigationController
        self.account = account
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
        let coinbaseAction = UIAlertAction(title: R.string.localizable.depositBuyButtonCoinbaseTitle(), style: .default) { _ in
            self.showCoinbase()
        }
        let shapeShiftAction = UIAlertAction(title: R.string.localizable.depositBuyButtonShapeShiftTitle(), style: .default) { _ in
            self.showShapeShift()
        }
        let changellyAction = UIAlertAction(title: R.string.localizable.depositBuyButtonChangellyTitle(), style: .default) { _ in
            self.showChangelly()
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
        navigationController.openURL(widget.url)
    }

    func showShapeShift() {
        let widget = ShapeShiftBuyWidget(
            address: account.address.description
        )
        navigationController.openURL(widget.url)
    }

    func showChangelly() {
        let widget = ChangellyBuyWidget(
            address: account.address.description
        )
        navigationController.openURL(widget.url)
    }
}
