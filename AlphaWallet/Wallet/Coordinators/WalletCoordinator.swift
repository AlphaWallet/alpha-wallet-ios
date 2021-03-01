// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol WalletCoordinatorDelegate: class {
    func didFinish(with account: Wallet, in coordinator: WalletCoordinator)
    func didCancel(in coordinator: WalletCoordinator)
}

class WalletCoordinator: Coordinator {
    private let config: Config
    private var keystore: Keystore
    private weak var importWalletViewController: ImportWalletViewController?
    private let analyticsCoordinator: AnalyticsCoordinator

    var navigationController: UINavigationController
    weak var delegate: WalletCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    init(
        config: Config,
        navigationController: UINavigationController = UINavigationController(),
        keystore: Keystore,
        analyticsCoordinator: AnalyticsCoordinator
    ) {
        self.config = config
        self.navigationController = navigationController
        self.keystore = keystore
        self.analyticsCoordinator = analyticsCoordinator
        navigationController.navigationBar.isTranslucent = false
    }

    ///Return true if caller should proceed to show UI (`navigationController`)
    @discardableResult func start(_ entryPoint: WalletEntryPoint) -> Bool {
        switch entryPoint {
        case .importWallet:
            let controller = ImportWalletViewController(keystore: keystore, analyticsCoordinator: analyticsCoordinator)
            controller.delegate = self
            controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(dismiss))
            navigationController.viewControllers = [controller]
            importWalletViewController = controller
        case .watchWallet(let address):
            let controller = ImportWalletViewController(keystore: keystore, analyticsCoordinator: analyticsCoordinator)
            controller.delegate = self
            controller.watchAddressTextField.value = address?.eip55String ?? ""
            controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(dismiss))
            controller.showWatchTab()
            navigationController.viewControllers = [controller]
            importWalletViewController = controller
        case .createInstantWallet:
            createInstantWallet()
            return false
        case .addInitialWallet:
            let controller = CreateInitialWalletViewController(keystore: keystore, analyticsCoordinator: analyticsCoordinator)
            controller.delegate = self
            controller.configure()
            navigationController.viewControllers = [controller]
        }
        return true
    }

    func pushImportWallet() {
        let controller = ImportWalletViewController(keystore: keystore, analyticsCoordinator: analyticsCoordinator)
        controller.delegate = self
        controller.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(controller, animated: true)
    }

    func createInitialWalletIfMissing() {
        if !keystore.hasWallets {
            let result = keystore.createAccount()
            switch result {
            case .success(let account):
                keystore.recentlyUsedWallet = Wallet(type: WalletType.real(account))
            case .failure:
                //TODO handle initial wallet creation error. App can't be used!
                break
            }
        }
    }

    //TODO Rename this is create in both settings and new install
    func createInstantWallet() {
        navigationController.displayLoading(text: R.string.localizable.walletCreateInProgress(), animated: false)
        keystore.createAccount { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let account):
                let wallet = Wallet(type: WalletType.real(account))
                //Bit of delay to wait for the UI animation to almost finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    WhereIsWalletAddressFoundOverlayView.show()
                }
                strongSelf.delegate?.didFinish(with: wallet, in: strongSelf)
            case .failure(let error):
                //TODO this wouldn't work since navigationController isn't shown anymore
                strongSelf.navigationController.displayError(error: error)
            }
            strongSelf.navigationController.hideLoading(animated: false)
        }
    }

    private func addWalletWith(entryPoint: WalletEntryPoint) {
        //Intentionally creating an instance of myself
        let coordinator = WalletCoordinator(config: config, keystore: keystore, analyticsCoordinator: analyticsCoordinator)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(entryPoint)
        coordinator.navigationController.makePresentationFullScreenForiOS13Migration()
        navigationController.present(coordinator.navigationController, animated: true)
    }

    @objc func dismiss() {
        delegate?.didCancel(in: self)
    }

    //TODO Rename this is import in both settings and new install
    func didCreateAccount(account: Wallet) {
        delegate?.didFinish(with: account, in: self)
        //Bit of delay to wait for the UI animation to almost finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            SuccessOverlayView.show()
        }
    }
}

extension WalletCoordinator: ImportWalletViewControllerDelegate {

    func openQRCode(in controller: ImportWalletViewController) {
        guard navigationController.ensureHasDeviceAuthorization() else { return }
        let scanQRCodeCoordinator = ScanQRCodeCoordinator(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, account: keystore.recentlyUsedWallet)
        let coordinator = QRCodeResolutionCoordinator(config: config, coordinator: scanQRCodeCoordinator, usage: .importWalletOnly)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(fromSource: .importWalletScreen)
    }

    func didImportAccount(account: Wallet, in viewController: ImportWalletViewController) {
        config.addToWalletAddressesAlreadyPromptedForBackup(address: account.address)
        didCreateAccount(account: account)
    }
}

extension WalletCoordinator: QRCodeResolutionCoordinatorDelegate {

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveAddress address: AlphaWallet.Address, action: ScanQRCodeAction) {
        removeCoordinator(coordinator)

        importWalletViewController?.set(tabSelection: .watch)
        importWalletViewController?.setValueForCurrentField(string: address.eip55String)
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveTransactionType transactionType: TransactionType, token: TokenObject) {
        removeCoordinator(coordinator)
        //no op
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveWalletConnectURL url: WalletConnectURL) {
        removeCoordinator(coordinator)
        //no op
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveString value: String) {
        removeCoordinator(coordinator)
        //no op
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveURL url: URL) {
        removeCoordinator(coordinator)
        //no op
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveJSON json: String) {
        removeCoordinator(coordinator)

        importWalletViewController?.set(tabSelection: .keystore)
        importWalletViewController?.setValueForCurrentField(string: json)
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveSeedPhase seedPhase: [String]) {
        removeCoordinator(coordinator)

        importWalletViewController?.set(tabSelection: .mnemonic)
        importWalletViewController?.setValueForCurrentField(string: seedPhase.joined(separator: " "))
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolvePrivateKey privateKey: String) {
        removeCoordinator(coordinator)

        importWalletViewController?.set(tabSelection: .privateKey)
        importWalletViewController?.setValueForCurrentField(string: privateKey)
    }

    func didCancel(in coordinator: QRCodeResolutionCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension WalletCoordinator: CreateInitialWalletViewControllerDelegate {

    func didTapCreateWallet(inViewController viewController: CreateInitialWalletViewController) {
        createInstantWallet()
    }

    func didTapWatchWallet(inViewController viewController: CreateInitialWalletViewController) {
        addWalletWith(entryPoint: .watchWallet(address: nil))
    }

    func didTapImportWallet(inViewController viewController: CreateInitialWalletViewController) {
        addWalletWith(entryPoint: .importWallet)
    }
}

extension WalletCoordinator: WalletCoordinatorDelegate {

    func didFinish(with account: Wallet, in coordinator: WalletCoordinator) {
        coordinator.navigationController.dismiss(animated: false)

        removeCoordinator(coordinator)
        delegate?.didFinish(with: account, in: self)
    }

    func didCancel(in coordinator: WalletCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)
    }
}
