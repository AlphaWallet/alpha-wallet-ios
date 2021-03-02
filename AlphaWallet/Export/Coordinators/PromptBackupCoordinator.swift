// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt

protocol PromptBackupCoordinatorProminentPromptDelegate: class {
    var viewControllerToShowBackupLaterAlert: UIViewController { get }

    func updatePrompt(inCoordinator coordinator: PromptBackupCoordinator)
}

protocol PromptBackupCoordinatorSubtlePromptDelegate: class {
    var viewControllerToShowBackupLaterAlert: UIViewController { get }

    func updatePrompt(inCoordinator coordinator: PromptBackupCoordinator)
}

class PromptBackupCoordinator: Coordinator {
    private static let secondsInAMonth = TimeInterval(30*24*60*60)
    private static let thresholdNativeCryptoCurrencyAmountInUsdToPromptBackup = Double(200)

    private let documentsDirectory = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
    private let filename = "backupState.json"
    lazy private var fileUrl = documentsDirectory.appendingPathComponent(filename)
    private let keystore: Keystore
    private let wallet: Wallet
    private let config: Config
    private let analyticsCoordinator: AnalyticsCoordinator
    //TODO this should be the total of mainnets instead of just Ethereum mainnet
    private var nativeCryptoCurrencyDollarValueInUsd: Double = 0

    var prominentPromptView: UIView?
    var subtlePromptView: UIView?
    var coordinators: [Coordinator] = []
    weak var prominentPromptDelegate: PromptBackupCoordinatorProminentPromptDelegate?
    weak var subtlePromptDelegate: PromptBackupCoordinatorSubtlePromptDelegate?

    init(keystore: Keystore, wallet: Wallet, config: Config, analyticsCoordinator: AnalyticsCoordinator) {
        self.keystore = keystore
        self.wallet = wallet
        self.config = config
        self.analyticsCoordinator = analyticsCoordinator
    }

    func start() {
        migrateOldData()
        guard canBackupWallet else { return }
        setUpAndPromptIfWalletHasNotBeenPromptedBefore()
        showCreateBackupAfterIntervalPrompt()
        showHideCurrentPrompt()
    }

    private func setUpAndPromptIfWalletHasNotBeenPromptedBefore() {
        guard !hasState else { return }
        updateState { state in
            state.backupState[wallet.address] = .init(shownNativeCryptoCurrencyReceivedPrompt: false, timeToShowIntervalPassedPrompt: nil, shownNativeCryptoCurrencyDollarValueExceedThresholdPrompt: false, lastBackedUpTime: nil, isImported: false)
        }
        showCreateBackupAfterWalletCreationPrompt()
    }

    func showHideCurrentPrompt() {
        if let prompt = readState()?.prompt[wallet.address] {
            switch prompt {
            case .newWallet:
                createBackupAfterWalletCreationView()
            case .intervalPassed:
                createBackupAfterIntervalView()
            case .nativeCryptoCurrencyDollarValueExceededThreshold:
                createBackupAfterExceedingThresholdView()
            case .receivedNativeCryptoCurrency(let nativeCryptoCurrency):
                createBackupAfterReceiveNativeCryptoCurrencyView(nativeCryptoCurrency: nativeCryptoCurrency)
            }
        } else {
            removeBackupView()
        }
    }

    private func informDelegatesPromptHasChanged() {
        subtlePromptDelegate?.updatePrompt(inCoordinator: self)
        prominentPromptDelegate?.updatePrompt(inCoordinator: self)
    }

    private func migrateOldData() {
        guard !FileManager.default.fileExists(atPath: fileUrl.path) else { return }
        let addressesAlreadyPromptedForBackup = config.oldWalletAddressesAlreadyPromptedForBackUp
        var walletsBackupState: WalletsBackupState = .init()
        for eachAlreadyBackedUp in addressesAlreadyPromptedForBackup {
            guard let walletAddress = AlphaWallet.Address(string: eachAlreadyBackedUp) else { continue }
            walletsBackupState.prompt[walletAddress] = nil
            //We'll just take the last backed up time as when this migration runs
            walletsBackupState.backupState[walletAddress] = .init(shownNativeCryptoCurrencyReceivedPrompt: true, timeToShowIntervalPassedPrompt: nil, shownNativeCryptoCurrencyDollarValueExceedThresholdPrompt: true, lastBackedUpTime: Date(), isImported: false)
        }
        writeState(walletsBackupState)
    }

    private func createBackupViewImpl(viewModel: PromptBackupWalletViewModel) -> UIView {
        let view = PromptBackupWalletView(viewModel: viewModel)
        view.delegate = self
        view.configure()
        return view
    }

    //TODO not the best way to watch Ether balance
    func listenToNativeCryptoCurrencyBalance(withTokenCollection tokenCollection: TokenCollection) {
        tokenCollection.subscribe { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let viewModel):
                if let nativeCryptoCurrencyToken = viewModel.nativeCryptoCurrencyToken(forServer: .main) {
                    let dollarValue = viewModel.amount(for: nativeCryptoCurrencyToken)
                    if !dollarValue.isZero {
                        strongSelf.showCreateBackupAfterExceedThresholdPrompt(valueInUsd: dollarValue)
                    }
                }
            case .failure:
                break
            }
        }
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
        let view = createBackupViewImpl(viewModel: PromptBackupWalletAfterExceedingThresholdViewViewModel(walletAddress: wallet.address, dollarValueInUsd: nativeCryptoCurrencyDollarValueInUsd))
        prominentPromptView = view
        subtlePromptView = nil
        informDelegatesPromptHasChanged()
    }

    private func removeBackupView() {
        prominentPromptView = nil
        subtlePromptView = nil
        informDelegatesPromptHasChanged()
    }

    // MARK: Set current prompt and state

    private func showCreateBackupAfterWalletCreationPrompt() {
        guard canBackupWallet else { return }
        guard !isBackedUp else { return }
        guard !isImported else { return }
        updateState { state in
            state.prompt[wallet.address] = .newWallet
            writeState(state)
        }
        showHideCurrentPrompt()
    }

    func showCreateBackupAfterReceiveNativeCryptoCurrencyPrompt(nativeCryptoCurrency: BigInt) {
        guard canBackupWallet else { return }
        guard !isBackedUp else { return }
        guard !isImported else { return }
        guard !hasShownNativeCryptoCurrencyReceivedPrompt else { return }
        updateState { state in
            state.prompt[wallet.address] = .receivedNativeCryptoCurrency(nativeCryptoCurrency)
            state.backupState[wallet.address]?.shownNativeCryptoCurrencyReceivedPrompt = true
            writeState(state)
        }
        showHideCurrentPrompt()
    }

    private func showCreateBackupAfterIntervalPrompt() {
        guard canBackupWallet else { return }
        guard !isBackedUp else { return }
        guard !isImported else { return }
        guard let time = timeToShowIntervalPassedPrompt else { return }
        guard time.isEarlierThan(date: .init()) else { return }
        updateState { state in
            state.prompt[wallet.address] = .intervalPassed
            state.backupState[wallet.address]?.timeToShowIntervalPassedPrompt = nil
            writeState(state)
        }
        showHideCurrentPrompt()
    }

    private func showCreateBackupAfterExceedThresholdPrompt(valueInUsd: Double) {
        nativeCryptoCurrencyDollarValueInUsd = valueInUsd
        guard canBackupWallet else { return }
        guard !isBackedUp else { return }
        guard !isImported else { return }
        let hasExceededThreshold = valueInUsd >= PromptBackupCoordinator.thresholdNativeCryptoCurrencyAmountInUsdToPromptBackup
        let toShow: Bool
        if isShowingExceededThresholdPrompt {
            if hasExceededThreshold {
                toShow = true
            } else {
                toShow = false
            }
        } else {
            guard !hasShownExceededThresholdPrompt else { return }
            guard hasExceededThreshold else { return }
            toShow = true
        }
        if toShow {
            updateState { state in
                state.prompt[wallet.address] = .nativeCryptoCurrencyDollarValueExceededThreshold
                state.backupState[wallet.address]?.shownNativeCryptoCurrencyDollarValueExceedThresholdPrompt = true
                writeState(state)
            }
            showHideCurrentPrompt()
        } else {
            updateState { state in
                state.prompt[wallet.address] = nil
                writeState(state)
            }
            showHideCurrentPrompt()
        }
    }

    func markBackupDone() {
        guard canBackupWallet else { return }
        updateState { state in
            state.prompt[wallet.address] = nil
            state.backupState[wallet.address]?.lastBackedUpTime = Date()
            writeState(state)
        }
    }

    private func remindLater() {
        guard canBackupWallet else { return }
        guard !isBackedUp else { return }
        guard !isImported else { return }
        updateState { state in
            state.prompt[wallet.address] = nil
            state.backupState[wallet.address]?.timeToShowIntervalPassedPrompt = Date(timeIntervalSinceNow: PromptBackupCoordinator.secondsInAMonth)
            writeState(state)
        }
    }

    func markWalletAsImported() {
        updateState { state in
            state.prompt[wallet.address] = nil
            if var backupState = state.backupState[wallet.address] {
                backupState.isImported = true
            } else {
                state.backupState[wallet.address] = .init(shownNativeCryptoCurrencyReceivedPrompt: false, timeToShowIntervalPassedPrompt: nil, shownNativeCryptoCurrencyDollarValueExceedThresholdPrompt: false, lastBackedUpTime: nil, isImported: true)
            }
            writeState(state)
        }
    }

    func deleteWallet() {
        updateState { state in
            state.prompt[wallet.address] = nil
            state.backupState[wallet.address] = nil
            writeState(state)
        }
    }

    // MARK: State

    private var hasState: Bool {
        guard let state = WalletsBackupState.load(fromUrl: fileUrl) else { return false }
        return state.backupState[wallet.address] != nil
    }

    private var hasShownNativeCryptoCurrencyReceivedPrompt: Bool {
        if let shown = readState()?.backupState[wallet.address]?.shownNativeCryptoCurrencyReceivedPrompt {
            return shown
        } else {
            return false
        }
    }

    private var hasShownExceededThresholdPrompt: Bool {
        if let shown = readState()?.backupState[wallet.address]?.shownNativeCryptoCurrencyDollarValueExceedThresholdPrompt {
            return shown
        } else {
            return false
        }
    }

    private var isBackedUp: Bool {
        return readState()?.backupState[wallet.address]?.lastBackedUpTime != nil
    }

    private var isImported: Bool {
        return readState()?.backupState[wallet.address]?.isImported ?? false
    }

    private var canBackupWallet: Bool {
        switch wallet.type {
        case .real:
            return true
        case .watch:
            return false
        }
    }

    private var isShowingExceededThresholdPrompt: Bool {
        guard let prompt = readState()?.prompt[wallet.address] else { return false }
        switch prompt {
        case .nativeCryptoCurrencyDollarValueExceededThreshold:
            return true
        case .newWallet, .intervalPassed, .receivedNativeCryptoCurrency:
            return false
        }
    }

    private var timeToShowIntervalPassedPrompt: Date? {
        return readState()?.backupState[wallet.address]?.timeToShowIntervalPassedPrompt
    }

    var securityLevel: WalletSecurityLevel? {
        switch wallet.type {
        case .real(let account):
            if isBackedUp || isImported {
                let isProtectedByUserPresence = keystore.isProtectedByUserPresence(account: account)
                if isProtectedByUserPresence {
                    return .backedUpWithElevatedSecurity
                } else {
                    return .backedUpButSecurityIsNotElevated
                }
            } else {
                return .notBackedUp
            }
        case .watch:
            return nil
        }
    }

    private func readState() -> WalletsBackupState? {
        return WalletsBackupState.load(fromUrl: fileUrl)
    }

    private func writeState(_ state: WalletsBackupState) {
        state.writeTo(url: fileUrl)
    }

    private func updateState(block: (inout WalletsBackupState) -> Void) {
        if var state = readState() {
            block(&state)
            writeState(state)
        }
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
        remindLater()
        showHideCurrentPrompt()
    }

    func didChooseBackup(inView view: PromptBackupWalletView) {
        guard let nc = viewControllerToShowBackupLaterAlert(forView: view)?.navigationController else { return }
        let coordinator = BackupCoordinator(navigationController: nc, keystore: keystore, account: wallet.address, analyticsCoordinator: analyticsCoordinator)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }
}

extension PromptBackupCoordinator: BackupCoordinatorDelegate {
    func didCancel(coordinator: BackupCoordinator) {
        removeCoordinator(coordinator)
    }

    func didFinish(account: AlphaWallet.Address, in coordinator: BackupCoordinator) {
        removeCoordinator(coordinator)
        markBackupDone()
        showHideCurrentPrompt()
    }
}
