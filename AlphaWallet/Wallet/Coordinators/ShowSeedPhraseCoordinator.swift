//
//  ShowSeedPhraseCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.03.2021.
//

import UIKit
import LocalAuthentication
import AlphaWalletFoundation

protocol ShowSeedPhraseCoordinatorDelegate: AnyObject {
    func didCancel(in coordinator: ShowSeedPhraseCoordinator)
}

class ShowSeedPhraseCoordinator: Coordinator {

    private var showSeedPhraseViewController: ShowSeedPhraseViewController? {
        navigationController.viewControllers.compactMap { $0 as? ShowSeedPhraseViewController }.first
    }

    private let account: AlphaWallet.Address
    private let keystore: Keystore
    private var _context: LAContext?
    private var context: LAContext {
        if let context = _context {
            return context
        } else {
            //TODO: This assumes we only access `context` when we going to use it immediately (and hence access biometrics). Can we make this more explicit?
            _isInactiveBecauseWeAccessingBiometrics = true
            let context = LAContext()
            _context = context
            return context
        }
    }
    //We have this flag because when prompted for Touch ID/Face ID, the app becomes inactive, and the order is:
    //1. we read the seed, thus the prompt shows up, making the app inactive
    //2. user authenticates and we get the seed
    //3. app is now notified as inactive! (note that this is after authentication succeeds)
    //4. app becomes active
    //Without this flag, we will be removing the seed in (3) and trying to read it in (4) again and triggering (1), thus going into an infinite loop of reading
    private var _isInactiveBecauseWeAccessingBiometrics = false

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: ShowSeedPhraseCoordinatorDelegate?

    init(navigationController: UINavigationController, keystore: Keystore, account: AlphaWallet.Address) {
        self.navigationController = navigationController
        self.keystore = keystore
        self.account = account

        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignsActive), name: UIApplication.willResignActiveNotification, object: nil)
    }

    func start() {
        let controller = ShowSeedPhraseIntroductionViewController()
        controller.delegate = self
        controller.navigationItem.largeTitleDisplayMode = .never

        navigationController.pushViewController(controller, animated: true)
    }

    private func createShowSeedPhraseViewController() -> ShowSeedPhraseViewController {
        var viewModel = ShowSeedPhraseViewModel(words: [])
        viewModel.subtitle = R.string.localizable.walletsShowSeedPhraseSubtitle2()
        viewModel.buttonTitle = R.string.localizable.walletsShowSeedPhraseHideSeedPhrase()

        let controller = ShowSeedPhraseViewController(keystore: keystore, account: account, viewModel: viewModel)
        controller.configure()
        controller.delegate = self

        return controller
    }

    //We need to call this after biometrics is cancelled so that when biometrics is accessed again (because it was cancelled, so it needs to be accessed again), we track background state correctly
    private func clearContext() {
        _context = nil
    }

    @objc private func appWillResignsActive() {
        if _isInactiveBecauseWeAccessingBiometrics {
            _isInactiveBecauseWeAccessingBiometrics = false
            return
        }
        _context = nil
        showSeedPhraseViewController?.removeSeedPhraseFromDisplay()
    }
}

extension ShowSeedPhraseCoordinator: ShowSeedPhraseViewControllerDelegate {
    // swiftlint:disable all
    var isInactiveBecauseWeAccessingBiometrics: Bool {
        get {
            return _isInactiveBecauseWeAccessingBiometrics
        }
        set {
            _isInactiveBecauseWeAccessingBiometrics = newValue
        }
    }
    // swiftlint:enable all

    var contextToShowSeedPhrase: LAContext {
        return context
    }

    func didTapTestSeedPhrase(for account: AlphaWallet.Address, inViewController viewController: ShowSeedPhraseViewController) {
        navigationController.popToRootViewController(animated: true)
        delegate?.didCancel(in: self)
    }

    func biometricsFailed(for account: AlphaWallet.Address, inViewController viewController: ShowSeedPhraseViewController) {
        clearContext()
    }
}

extension ShowSeedPhraseCoordinator: ShowSeedPhraseIntroductionViewControllerDelegate {

    func didShowSeedPhrase(in viewController: ShowSeedPhraseIntroductionViewController) {
        let controller = createShowSeedPhraseViewController()
        controller.navigationItem.largeTitleDisplayMode = .never

        navigationController.pushViewController(controller, animated: true)
    }

    func didClose(in viewController: ShowSeedPhraseIntroductionViewController) {
        navigationController.popViewController(animated: true)
        delegate?.didCancel(in: self)
    }
}

