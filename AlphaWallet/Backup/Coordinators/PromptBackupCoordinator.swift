// Copyright © 2019 Stormbird PTE. LTD.

import UIKit
import BigInt
import Combine
import AlphaWalletFoundation

protocol PromptBackupCoordinatorProminentPromptDelegate: AnyObject {
    var viewControllerToShowBackupLaterAlert: UIViewController { get }

    func updatePrompt(inCoordinator coordinator: PromptBackupCoordinator)
}

protocol PromptBackupCoordinatorSubtlePromptDelegate: AnyObject {
    var viewControllerToShowBackupLaterAlert: UIViewController { get }

    func updatePrompt(inCoordinator coordinator: PromptBackupCoordinator)
}

class PromptBackupCoordinator: Coordinator {
    private let keystore: Keystore
    private let wallet: Wallet
    private let analytics: AnalyticsLogger
    private let promptBackup: PromptBackup
    private var cancellable = Set<AnyCancellable>()

    private (set) var prominentPromptView: UIView?
    private (set) var subtlePromptView: UIView?
    var coordinators: [Coordinator] = []

    weak var prominentPromptDelegate: PromptBackupCoordinatorProminentPromptDelegate?
    weak var subtlePromptDelegate: PromptBackupCoordinatorSubtlePromptDelegate?

    init(wallet: Wallet,
         promptBackup: PromptBackup,
         keystore: Keystore,
         analytics: AnalyticsLogger) {

        self.keystore = keystore
        self.analytics = analytics
        self.wallet = wallet
        self.promptBackup = promptBackup

        promptBackup.promptEvent
            .filter { $0 == wallet }
            .sink { [weak self] event in
                switch event {
                case .show(_, let prompt):
                    switch prompt {
                    case .newWallet:
                        self?.createBackupAfterWalletCreationView()
                    case .intervalPassed:
                        self?.createBackupAfterIntervalView()
                    case .balanceExceededThreshold:
                        self?.createBackupAfterExceedingThresholdView()
                    case .receivedNativeCryptoCurrency(let nativeCryptoCurrency):
                        self?.createBackupAfterReceiveNativeCryptoCurrencyView(nativeCryptoCurrency: nativeCryptoCurrency)
                    }
                case .hideBackupView:
                    self?.removeBackupView()
                }
            }.store(in: &cancellable)
    }

    func start() {
        promptBackup.start(wallet: wallet)
    }

    private func informDelegatesPromptHasChanged() {
        subtlePromptDelegate?.updatePrompt(inCoordinator: self)
        prominentPromptDelegate?.updatePrompt(inCoordinator: self)
    }

    private func createBackupViewImpl(viewModel: PromptBackupWalletViewModel, callerFunctionName: String = #function) -> UIView {
        infoLog("Prompting backup", callerFunctionName: callerFunctionName)
        let view = PromptBackupWalletView(viewModel: viewModel)
        view.delegate = self
        view.configure()
        return view
    }

    // MARK: Update UI
    private func createBackupAfterWalletCreationView() {
        let view = createBackupViewImpl(viewModel: PromptBackupWalletAfterWalletCreationViewViewModel(walletAddress: wallet.address))
        prominentPromptView = nil
        subtlePromptView = view
        informDelegatesPromptHasChanged()
    }

    private func createBackupAfterReceiveNativeCryptoCurrencyView(nativeCryptoCurrency: BigInt) {
        let view = createBackupViewImpl(viewModel: PromptBackupWalletAfterReceivingNativeCryptoCurrencyViewViewModel(walletAddress: wallet.address, nativeCryptoCurrency: nativeCryptoCurrency))
        prominentPromptView = view
        subtlePromptView = nil
        informDelegatesPromptHasChanged()
    }

    private func createBackupAfterIntervalView() {
        let view = createBackupViewImpl(viewModel: PromptBackupWalletAfterIntervalViewViewModel(walletAddress: wallet.address))
        prominentPromptView = view
        subtlePromptView = nil
        informDelegatesPromptHasChanged()
    }

    private func createBackupAfterExceedingThresholdView() {
        let balance = promptBackup.balance(wallet: wallet)
        let view = createBackupViewImpl(viewModel: PromptBackupWalletAfterExceedingThresholdViewViewModel(walletAddress: wallet.address, balance: balance))
        prominentPromptView = view
        subtlePromptView = nil
        informDelegatesPromptHasChanged()
    }

    private func removeBackupView() {
        prominentPromptView = nil
        subtlePromptView = nil
        informDelegatesPromptHasChanged()
    }
}

extension PromptBackupCoordinator: PromptBackupWalletViewDelegate {
    func viewControllerToShowBackupLaterAlert(forView view: PromptBackupWalletView) -> UIViewController? {
        switch view {
        case prominentPromptView:
            return prominentPromptDelegate?.viewControllerToShowBackupLaterAlert
        case subtlePromptView:
            return subtlePromptDelegate?.viewControllerToShowBackupLaterAlert
        default:
            return nil
        }
    }

    func didChooseBackupLater(inView view: PromptBackupWalletView) {
        promptBackup.remindLater(wallet: wallet)
    }

    func didChooseBackup(inView view: PromptBackupWalletView) {
        guard let nc = viewControllerToShowBackupLaterAlert(forView: view)?.navigationController else { return }
        let coordinator = BackupCoordinator(
            navigationController: nc,
            keystore: keystore,
            account: wallet,
            analytics: analytics,
            promptBackup: promptBackup)

        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }
}

extension PromptBackupCoordinator: BackupCoordinatorDelegate {
    func didCancel(in coordinator: BackupCoordinator) {
        removeCoordinator(coordinator)
    }

    func didFinish(account: AlphaWallet.Address, in coordinator: BackupCoordinator) {
        removeCoordinator(coordinator)
    }
}
