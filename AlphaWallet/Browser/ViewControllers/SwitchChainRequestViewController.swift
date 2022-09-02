//
//  SwitchChainRequestViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.09.2021.
//

import UIKit
import PromiseKit
import AlphaWalletFoundation

protocol SwitchChainRequestViewControllerDelegate: class {
    func didClose(in viewController: SwitchChainRequestViewController)
    func didSelectActionButton(in viewController: SwitchChainRequestViewController)
    func didSelectAdditionalButton(in viewController: SwitchChainRequestViewController)
}

class SwitchChainRequestViewController: ModalViewController {
    weak var _delegate: SwitchChainRequestViewControllerDelegate?

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
    private lazy var enableTestnetButton: Button = {
        let button = Button(size: .normal, style: .system)
        button.setTitle(viewModel.additionalButtonTitle, for: .normal)

        return button
    }()

    private lazy var buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        return buttonsBar
    }()

    private var viewModel: SwitchChainRequestViewModel

    init(viewModel: SwitchChainRequestViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        let footerView = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)

        footerStackView.addArrangedSubview(footerView)
        generateSubviews()
        presentationDelegate = self

        enableTestnetButton.addTarget(self, action: #selector(enableTestnetButtonSelected), for: .touchUpInside)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: SwitchChainRequestViewModel) {
        self.viewModel = viewModel
        generateSubviews()

        buttonsBar.configure()
        buttonsBar.buttons[0].setTitle(viewModel.actionButtonTitle, for: .normal)
        buttonsBar.buttons[0].addTarget(self, action: #selector(actionButtonSelected), for: .touchUpInside)

        titleLabel.text = viewModel.title
        descriptionLabel.text = viewModel.description
    }

    @objc private func actionButtonSelected(_ sender: UIButton) {
        dismissViewAnimated(with: {
            self._delegate?.didSelectActionButton(in: self)
            self.dismiss(animated: false)
        })
    }

    @objc private func enableTestnetButtonSelected(_ sender: UIButton) {
        dismissViewAnimated(with: {
            self._delegate?.didSelectAdditionalButton(in: self)
            self.dismiss(animated: false)
        })
    }
}

extension SwitchChainRequestViewController: ModalViewControllerDelegate {

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

extension SwitchChainRequestViewController {
    private func generateSubviews() {
        stackView.removeAllArrangedSubviews()

        var views: [UIView] = [
            [.spacerWidth(16), titleLabel, .spacerWidth(16)].asStackView(axis: .horizontal),
            .spacer(height: 20),
            [.spacerWidth(16), descriptionLabel, .spacerWidth(16)].asStackView(axis: .horizontal),
        ]

        switch viewModel.configuration {
        case .promptAndSwitchToExistingServerInBrowser, .promptAndActivateExistingServer:
            break
        case .promptAndAddAndActivateServer:
            views += [
                .spacer(height: 20),
                enableTestnetButton
            ]
        }

        stackView.addArrangedSubviews(views)
    }
}

private class SwitchChainRequestViewControllerBridgeToPromise: NSObject {

    private let (promiseToReturn, seal) = Promise<SwitchChainRequestResponse>.pending()
    private var retainCycle: SwitchChainRequestViewControllerBridgeToPromise?
    private let viewController: SwitchChainRequestViewController

    init(viewController target: UIViewController, configuration: SwitchChainRequestConfiguration) {
        viewController = SwitchChainRequestViewController(viewModel: .init(configuration: configuration))
        viewController.configure(viewModel: .init(configuration: configuration))

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

extension SwitchChainRequestViewControllerBridgeToPromise: SwitchChainRequestViewControllerDelegate {
    //NOTE: need to update it with more clear solution, passing button index isn't goo idea for that
    func didSelectActionButton(in viewController: SwitchChainRequestViewController) {
        seal.fulfill(.action(0))
    }

    func didSelectAdditionalButton(in viewController: SwitchChainRequestViewController) {
        seal.fulfill(.action(1))
    }

    func didClose(in viewController: SwitchChainRequestViewController) {
        seal.fulfill(.canceled)
    }
}

extension SwitchChainRequestViewController {
    static func promise(_ viewController: UIViewController, configuration: SwitchChainRequestConfiguration) -> Promise<SwitchChainRequestResponse> {
        return SwitchChainRequestViewControllerBridgeToPromise(viewController: viewController, configuration: configuration).promise
    }
}

