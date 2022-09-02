//
//  WalletConnectConnectionTimeoutViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.10.2021.
//

import UIKit
import PromiseKit
import AlphaWalletFoundation

struct WalletConnectConnectionTimeoutViewModel {
    let title: String = R.string.localizable.walletConnectErrorConnectionTimeoutTitle()

    var errorMessage: String

    var actionButtonTitle: String {
        return R.string.localizable.walletConnectScanQRCodeAgain()
    }

    init(errorMessage: String) {
        self.errorMessage = errorMessage
    }
}

protocol WalletConnectConnectionTimeoutViewControllerDelegate: class {
    func didClose(in viewController: WalletConnectConnectionTimeoutViewController)
    func didSelectActionButton(in viewController: WalletConnectConnectionTimeoutViewController)
}

class WalletConnectConnectionTimeoutViewController: ModalViewController {
    weak var _delegate: WalletConnectConnectionTimeoutViewControllerDelegate?

    private var titleLabel: UILabel = {
        let v = UILabel()
        v.numberOfLines = 0
        v.textAlignment = .center
        v.textColor = R.color.black()
        v.font = Fonts.bold(size: 24)

        return v
    }()

    private var descriptionLabel: UILabel = {
        let v = UILabel()
        v.numberOfLines = 0
        v.textAlignment = .center
        v.textColor = R.color.mine()
        v.font = Fonts.regular(size: 17)

        return v
    }()

    private lazy var buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        return buttonsBar
    }()

    private var viewModel: WalletConnectConnectionTimeoutViewModel

    init(viewModel: WalletConnectConnectionTimeoutViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        let footerView = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)

        footerStackView.addArrangedSubview(footerView)
        generateSubviews()
        presentationDelegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: WalletConnectConnectionTimeoutViewModel) {
        self.viewModel = viewModel
        generateSubviews()

        buttonsBar.configure()
        buttonsBar.buttons[0].setTitle(viewModel.actionButtonTitle, for: .normal)
        buttonsBar.buttons[0].addTarget(self, action: #selector(actionButtonSelected), for: .touchUpInside)

        titleLabel.text = viewModel.title
        descriptionLabel.text = viewModel.errorMessage
    }

    func dismissAnimated(completion: @escaping () -> Void) {
        dismissViewAnimated(with: {
            self._delegate?.didClose(in: self)
            self.dismiss(animated: false)
            completion()
        })
    }

    @objc private func actionButtonSelected(_ sender: UIButton) {
        dismissViewAnimated(with: {
            self._delegate?.didSelectActionButton(in: self)
            self.dismiss(animated: false)
        })
    }
}

extension WalletConnectConnectionTimeoutViewController: ModalViewControllerDelegate {

    func didDismiss(_ controller: ModalViewController) {
        _delegate?.didClose(in: self)
        dismiss(animated: false)
    }

    func didClose(_ controller: ModalViewController) {
        dismissViewAnimated(with: {
            self._delegate?.didClose(in: self)
            self.dismiss(animated: false)
        })
    }
}

extension WalletConnectConnectionTimeoutViewController {
    private func generateSubviews() {
        stackView.removeAllArrangedSubviews()

        let views: [UIView] = [
            [.spacerWidth(16), titleLabel, .spacerWidth(16)].asStackView(axis: .horizontal),
            .spacer(height: 20),
            [.spacerWidth(16), descriptionLabel, .spacerWidth(16)].asStackView(axis: .horizontal),
        ]

        stackView.addArrangedSubviews(views)
    }
}

private class WalletConnectConnectionTimeoutViewControllerBridgeToPromise: NSObject {

    private let (promiseToReturn, seal) = Promise<SwitchChainRequestResponse>.pending()
    private var retainCycle: WalletConnectConnectionTimeoutViewControllerBridgeToPromise?
    let viewController: WalletConnectConnectionTimeoutViewController

    init(viewController target: UIViewController, errorMessage: String) {
        viewController = WalletConnectConnectionTimeoutViewController(viewModel: .init(errorMessage: errorMessage))
        viewController.configure(viewModel: .init(errorMessage: errorMessage))

        super.init()
        retainCycle = self

        viewController._delegate = self
        promiseToReturn.ensure {
            // ensure we break the retain cycle
            self.retainCycle = nil
        }.cauterize()

        target.present(viewController, animated: false)
    }

    var promise: Promise<SwitchChainRequestResponse> {
        return promiseToReturn
    }
}

extension WalletConnectConnectionTimeoutViewControllerBridgeToPromise: WalletConnectConnectionTimeoutViewControllerDelegate {
    //NOTE: need to update it with more clear solution, passing button index isn't goo idea for that
    func didSelectActionButton(in viewController: WalletConnectConnectionTimeoutViewController) {
        seal.fulfill(.action(0))
    }

    func didClose(in viewController: WalletConnectConnectionTimeoutViewController) {
        seal.fulfill(.canceled)
    }
}

extension WalletConnectConnectionTimeoutViewController {
    static func promise(_ viewController: UIViewController, errorMessage: String) -> (viewController: UIViewController, promise: Promise<SwitchChainRequestResponse>) {
        let controller = WalletConnectConnectionTimeoutViewControllerBridgeToPromise(viewController: viewController, errorMessage: errorMessage)
        return (controller.viewController, controller.promise)
    }
}
