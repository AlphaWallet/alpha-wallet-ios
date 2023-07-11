// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import AlphaWalletFoundation
import Combine

protocol WalletCoordinatorDelegate: AnyObject {
    func didFinish(with account: Wallet, in coordinator: WalletCoordinator)
    func didCancel(in coordinator: WalletCoordinator)
}

class WalletCoordinator: Coordinator {
    private let config: Config
    private var keystore: Keystore
    private weak var importWalletViewController: ImportWalletViewController?
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainNameResolutionServiceType
    private var cancellable = Set<AnyCancellable>()

    var navigationController: UINavigationController
    weak var delegate: WalletCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    init(config: Config,
         navigationController: UINavigationController = NavigationController(),
         keystore: Keystore,
         analytics: AnalyticsLogger,
         domainResolutionService: DomainNameResolutionServiceType) {

        self.config = config
        self.navigationController = navigationController
        self.keystore = keystore
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
        navigationController.navigationBar.isTranslucent = false
    }

    ///Return true if caller should proceed to show UI (`navigationController`)
    @discardableResult func start(_ entryPoint: WalletEntryPoint) -> Bool {
        switch entryPoint {
        case .importWallet(let params):
            let controller = ImportWalletViewController(keystore: keystore, analytics: analytics, domainResolutionService: domainResolutionService)
            controller.delegate = self
            switch params {
            case .json(let json):
                controller.set(tabSelection: .keystore)
                controller.setValueForCurrentField(string: json)
            case .seedPhase(let seedPhase):
                controller.set(tabSelection: .mnemonic)
                controller.setValueForCurrentField(string: seedPhase.joined(separator: " "))
            case .privateKey(let privateKey):
                controller.set(tabSelection: .privateKey)
                controller.setValueForCurrentField(string: privateKey)
            case .none:
                break
            }
            controller.navigationItem.rightBarButtonItem = UIBarButtonItem.cancelBarButton(self, selector: #selector(dismissDidSelected))
            navigationController.viewControllers = [controller]
            importWalletViewController = controller
        case .watchWallet(let address):
            let controller = ImportWalletViewController(keystore: keystore, analytics: analytics, domainResolutionService: domainResolutionService)
            controller.delegate = self
            controller.watchAddressTextField.value = address?.eip55String ?? ""
            controller.navigationItem.rightBarButtonItem = UIBarButtonItem.cancelBarButton(self, selector: #selector(dismissDidSelected))
            controller.showWatchTab()
            navigationController.viewControllers = [controller]
            importWalletViewController = controller
        case .createInstantWallet:
            createInstantWallet()
            return false
        case .addInitialWallet:
            let controller = CreateInitialWalletViewController(keystore: keystore)
            controller.delegate = self
            controller.configure()
            navigationController.viewControllers = [controller]
        case .addHardwareWallet:
            if BCHardwareWallet.isEnabled {
                addHardwareWallet()
            } else {
                //no-op
            }
            return false
        }
        return true
    }

    func pushImportWallet() {
        let controller = ImportWalletViewController(keystore: keystore, analytics: analytics, domainResolutionService: domainResolutionService)
        controller.delegate = self
        controller.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(controller, animated: true)
    }

    //TODO Rename this is create in both settings and new install
    private func createInstantWallet() {
        //NOTE: don't use weak ref here
        navigationController.displayLoading(text: R.string.localizable.walletCreateInProgress(), animated: false)
        keystore.createHDWallet()
            .sink(receiveCompletion: { result in
                self.navigationController.hideLoading(animated: false)
                if case .failure(let error) = result {
                    self.navigationController.displayError(error: error)
                }
            }, receiveValue: { wallet in
                WhatsNewExperimentCoordinator.lastCreatedWalletTimestamp = Date()
                self.didImportAccount(account: wallet)
            }).store(in: &cancellable)
    }

    private func addWalletWith(entryPoint: WalletEntryPoint) {
        //Intentionally creating an instance of myself
        let coordinator = WalletCoordinator(config: config, keystore: keystore, analytics: analytics, domainResolutionService: domainResolutionService)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(entryPoint)
        coordinator.navigationController.makePresentationFullScreenForiOS13Migration()
        navigationController.present(coordinator.navigationController, animated: true)
    }

    @objc private func dismissDidSelected(_ sender: UIBarButtonItem) {
        delegate?.didCancel(in: self)
    }

    private func didImportAccount(account: Wallet) {
        delegate?.didFinish(with: account, in: self)
        //Bit of delay to wait for the UI animation to almost finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            SuccessOverlayView.show()
        }
    }

    private func addHardwareWallet() {
        let hwWallet = BCHardwareWalletCreator().createWallet()
        Task { @MainActor in
            do {
                let address = try await hwWallet.getAddress()
                keystore
                    .addHardwareWallet(address: address)
                    .sink(receiveCompletion: { result in
                        switch result {
                        case .finished:
                            break
                        case .failure:
                            //TODO: show an error, especially if the address/card has already been added
                            break
                        }
                    }, receiveValue: { wallet in
                        self.didImportAccount(account: wallet)
                    }).store(in: &cancellable)
            } catch {
                if error.isCancelledBChainRequest {
                    //no-op
                } else {
                    //no-op because already shown in the NFC UI
                    //TODO but error displayed can be more user friendly. E.g. try not using biometrics when required
                }
            }
        }
    }
}

extension WalletCoordinator: ImportWalletViewControllerDelegate {

    func openQRCode(in controller: ImportWalletViewController) {
        guard navigationController.ensureHasDeviceAuthorization() else { return }
        let scanQRCodeCoordinator = ScanQRCodeCoordinator(
            analytics: analytics,
            navigationController: navigationController,
            account: keystore.currentWallet,
            domainResolutionService: domainResolutionService)

        let coordinator = QRCodeResolutionCoordinator(
            coordinator: scanQRCodeCoordinator,
            usage: .importWalletOnly,
            supportedResolutions: QRCodeResolutionCoordinator.SupportedQrCodeResolution.jsonOrSeedPhraseResolution)

        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(fromSource: .importWalletScreen)
    }

    func didImportAccount(account: Wallet, in viewController: ImportWalletViewController) {
        config.addToWalletAddressesAlreadyPromptedForBackup(address: account.address)
        didImportAccount(account: account)
    }
}

extension WalletCoordinator: QRCodeResolutionCoordinatorDelegate {

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolve qrCodeResolution: QrCodeResolution) {
        switch qrCodeResolution {
        case .walletConnectUrl, .transactionType, .url, .string, .attestation:
            break
        case .address(let address, _):
            importWalletViewController?.set(tabSelection: .watch)
            importWalletViewController?.setValueForCurrentField(string: address.eip55String)
        case .json(let json):
            importWalletViewController?.set(tabSelection: .keystore)
            importWalletViewController?.setValueForCurrentField(string: json)
        case .seedPhase(let seedPhase):
            importWalletViewController?.set(tabSelection: .mnemonic)
            importWalletViewController?.setValueForCurrentField(string: seedPhase.joined(separator: " "))
        case .privateKey(let privateKey):
            importWalletViewController?.set(tabSelection: .privateKey)
            importWalletViewController?.setValueForCurrentField(string: privateKey)
        }

        removeCoordinator(coordinator)
    }

    func didCancel(in coordinator: QRCodeResolutionCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension WalletCoordinator: CreateInitialWalletViewControllerDelegate {

    func didTapCreateWallet(inViewController viewController: CreateInitialWalletViewController) {
        logInitialAction(.create)
        createInstantWallet()
    }

    func didTapWatchWallet(inViewController viewController: CreateInitialWalletViewController) {
        logInitialAction(.watch)
        addWalletWith(entryPoint: .watchWallet(address: nil))
    }

    func didTapImportWallet(inViewController viewController: CreateInitialWalletViewController) {
        logInitialAction(.import)
        addWalletWith(entryPoint: .importWallet(params: nil))
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

// MARK: Analytics
extension WalletCoordinator {
    private func logInitialAction(_ action: Analytics.FirstWalletAction) {
        analytics.log(action: Analytics.Action.firstWalletAction, properties: [Analytics.Properties.type.rawValue: action.rawValue])
    }
}
