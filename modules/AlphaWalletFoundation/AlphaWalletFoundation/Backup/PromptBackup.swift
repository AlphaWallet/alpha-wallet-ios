//
//  PromptBackup.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 29.12.2022.
//

import Foundation
import BigInt
import Combine

public protocol WalletBalanceProvidable {
    func walletBalance(for wallet: Wallet) -> AnyPublisher<WalletBalance, Never>
}

extension MultiWalletBalanceService: WalletBalanceProvidable { }

public class PromptBackup {
    //Explicit `TimeInterval()` to speed up compilation
    private static let secondsInAMonth = TimeInterval(30) * 24 * 60 * 60
    private static let thresholdNativeCryptoCurrencyAmountInFiatToPromptBackup = Double(200)
    private let filename: String
    private lazy var fileUrl: URL = {
        let documentsDirectory = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
        return documentsDirectory.appendingPathComponent(filename)
    }()

    private let keystore: Keystore
    private let config: Config
    private let analytics: AnalyticsLogger
    private let walletBalanceProvidable: WalletBalanceProvidable
    //TODO this should be the total of mainnets instead of just Ethereum mainnet
    private var balances: [Wallet: WalletBalance.ValueForCurrency] = [:]
    private var cancelable = Set<AnyCancellable>()
    private let promptEventSubject = PassthroughSubject<PromptEvent, Never>()

    public var promptEvent: AnyPublisher<PromptBackup.PromptEvent, Never> {
        return promptEventSubject
            .eraseToAnyPublisher()
    }

    public init(keystore: Keystore,
                config: Config,
                analytics: AnalyticsLogger,
                walletBalanceProvidable: WalletBalanceProvidable,
                filename: String = "backupState.json") {

        self.filename = filename
        self.walletBalanceProvidable = walletBalanceProvidable
        self.keystore = keystore
        self.config = config
        self.analytics = analytics
    }

    public func start(wallet: Wallet) {
        cancelable.cancellAll()
        listenToNativeCryptoCurrencyBalance(wallet: wallet)
        migrateOldData()
        guard canBackupWallet(wallet: wallet) else { return }
        setUpAndPromptIfWalletHasNotBeenPromptedBefore(wallet: wallet)
        showCreateBackupAfterIntervalPrompt(wallet: wallet)
        showHideCurrentPrompt(wallet: wallet)
    }

    private func setUpAndPromptIfWalletHasNotBeenPromptedBefore(wallet: Wallet) {
        guard !hasState(wallet: wallet) else { return }
        updateState { state in
            state.backupState[wallet.address] = .init(
                shownNativeCryptoCurrencyReceivedPrompt: false,
                timeToShowIntervalPassedPrompt: nil,
                shownNativeCryptoCurrencyDollarValueExceedThresholdPrompt: false,
                lastBackedUpTime: nil,
                isImported: false)
        }
        showCreateBackupAfterWalletCreationPrompt(wallet: wallet)
    }

    private func showHideCurrentPrompt(wallet: Wallet) {
        if let prompt = readState()?.prompt[wallet.address] {
            promptEventSubject.send(.show(wallet: wallet, prompt: prompt))
        } else {
            promptEventSubject.send(.hideBackupView(wallet: wallet))
        }
    }

    //TODO: improve balance fetching
    public func balance(wallet: Wallet) -> WalletBalance.ValueForCurrency {
        balances[wallet] ?? .init(amount: 0, currency: .default)
    }

    private func migrateOldData() {
        guard !FileManager.default.fileExists(atPath: fileUrl.path) else { return }
        let addressesAlreadyPromptedForBackup = config.oldWalletAddressesAlreadyPromptedForBackUp
        var walletsBackupState: WalletsBackupState = .init()
        for eachAlreadyBackedUp in addressesAlreadyPromptedForBackup {
            guard let walletAddress = AlphaWallet.Address(string: eachAlreadyBackedUp) else { continue }
            walletsBackupState.prompt[walletAddress] = nil
            //We'll just take the last backed up time as when this migration runs
            walletsBackupState.backupState[walletAddress] = .init(
                shownNativeCryptoCurrencyReceivedPrompt: true,
                timeToShowIntervalPassedPrompt: nil,
                shownNativeCryptoCurrencyDollarValueExceedThresholdPrompt: true,
                lastBackedUpTime: Date(),
                isImported: false)
        }
        writeState(walletsBackupState)
    }

    private func listenToNativeCryptoCurrencyBalance(wallet: Wallet) {
        walletBalanceProvidable
            .walletBalance(for: wallet)
            .compactMap { $0.totalAmount }
            .sink { [weak self] in self?.showCreateBackupAfterExceedThresholdPrompt(wallet: wallet, balance: $0) }
            .store(in: &cancelable)
    }

    //NOTE: looks like this never get called
    private func showCreateBackupAfterWalletCreationPrompt(wallet: Wallet) {
        guard canBackupWallet(wallet: wallet) else { return }
        guard !isBackedUp(wallet: wallet) else { return }
        guard !isImported(wallet: wallet) else { return }
        updateState { state in
            state.prompt[wallet.address] = .newWallet
            writeState(state)
        }
        showHideCurrentPrompt(wallet: wallet)
    }

    public func showCreateBackupAfterReceiveNativeCryptoCurrencyPrompt(wallet: Wallet, etherReceived: BigInt) {
        guard canBackupWallet(wallet: wallet) else { return }
        guard !isBackedUp(wallet: wallet) else { return }
        guard !isImported(wallet: wallet) else { return }
        guard !hasShownNativeCryptoCurrencyReceivedPrompt(wallet: wallet) else { return }
        updateState { state in
            state.prompt[wallet.address] = .receivedNativeCryptoCurrency(etherReceived)
            state.backupState[wallet.address]?.shownNativeCryptoCurrencyReceivedPrompt = true
            writeState(state)
        }
        showHideCurrentPrompt(wallet: wallet)
    }

    private func showCreateBackupAfterIntervalPrompt(wallet: Wallet) {
        guard canBackupWallet(wallet: wallet) else { return }
        guard !isBackedUp(wallet: wallet) else { return }
        guard !isImported(wallet: wallet) else { return }
        guard let time = timeToShowIntervalPassedPrompt(wallet: wallet) else { return }
        guard time.isEarlierThan(date: .init()) else { return }
        updateState { state in
            state.prompt[wallet.address] = .intervalPassed
            state.backupState[wallet.address]?.timeToShowIntervalPassedPrompt = nil
            writeState(state)
        }
        showHideCurrentPrompt(wallet: wallet)
    }

    private func showCreateBackupAfterExceedThresholdPrompt(wallet: Wallet, balance: WalletBalance.ValueForCurrency) {
        self.balances[wallet] = balance
        guard canBackupWallet(wallet: wallet) else { return }
        guard !isBackedUp(wallet: wallet) else { return }
        guard !isImported(wallet: wallet) else { return }

        let hasExceededThreshold = balance.amount >= PromptBackup.thresholdNativeCryptoCurrencyAmountInFiatToPromptBackup
        let toShow: Bool
        if isShowingExceededThresholdPrompt(wallet: wallet) {
            toShow = hasExceededThreshold
        } else {
            guard !hasShownExceededThresholdPrompt(wallet: wallet) else { return }
            guard hasExceededThreshold else { return }
            toShow = true
        }
        if toShow {
            updateState { state in
                state.prompt[wallet.address] = .balanceExceededThreshold
                state.backupState[wallet.address]?.shownNativeCryptoCurrencyDollarValueExceedThresholdPrompt = true
                writeState(state)
            }
            showHideCurrentPrompt(wallet: wallet)
        } else {
            updateState { state in
                state.prompt[wallet.address] = nil
                writeState(state)
            }
            showHideCurrentPrompt(wallet: wallet)
        }
    }

    public func markBackupDone(wallet: Wallet) {
        defer { showHideCurrentPrompt(wallet: wallet) }
        guard canBackupWallet(wallet: wallet) else { return }
        updateState { state in
            state.prompt[wallet.address] = nil
            state.backupState[wallet.address]?.lastBackedUpTime = Date()
            writeState(state)
        }
    }

    public func remindLater(wallet: Wallet) {
        defer { showHideCurrentPrompt(wallet: wallet) }
        guard canBackupWallet(wallet: wallet) else { return }
        updateState { state in
            state.prompt[wallet.address] = nil
            state.backupState[wallet.address]?.timeToShowIntervalPassedPrompt = Date(timeIntervalSinceNow: PromptBackup.secondsInAMonth)
            writeState(state)
        }
    }

    public func markWalletAsImported(wallet: Wallet) {
        updateState { state in
            state.prompt[wallet.address] = nil
            if var backupState = state.backupState[wallet.address] {
                backupState.isImported = true
            } else {
                state.backupState[wallet.address] = .init(
                    shownNativeCryptoCurrencyReceivedPrompt: false,
                    timeToShowIntervalPassedPrompt: nil,
                    shownNativeCryptoCurrencyDollarValueExceedThresholdPrompt: false,
                    lastBackedUpTime: nil,
                    isImported: true)
            }
            writeState(state)
        }
    }

    public func deleteWallet(wallet: Wallet) {
        updateState { state in
            state.prompt[wallet.address] = nil
            state.backupState[wallet.address] = nil
            writeState(state)
        }
    }

    // MARK: State

    private func hasState(wallet: Wallet) -> Bool {
        guard let state = WalletsBackupState.load(fromUrl: fileUrl) else { return false }
        return state.backupState[wallet.address] != nil
    }

    private func hasShownNativeCryptoCurrencyReceivedPrompt(wallet: Wallet) -> Bool {
        if let shown = readState()?.backupState[wallet.address]?.shownNativeCryptoCurrencyReceivedPrompt {
            return shown
        } else {
            return false
        }
    }

    private func hasShownExceededThresholdPrompt(wallet: Wallet) -> Bool {
        if let shown = readState()?.backupState[wallet.address]?.shownNativeCryptoCurrencyDollarValueExceedThresholdPrompt {
            return shown
        } else {
            return false
        }
    }

    private func isBackedUp(wallet: Wallet) -> Bool {
        return readState()?.backupState[wallet.address]?.lastBackedUpTime != nil
    }

    private func isImported(wallet: Wallet) -> Bool {
        return readState()?.backupState[wallet.address]?.isImported ?? false
    }

    private func canBackupWallet(wallet: Wallet) -> Bool {
        switch wallet.type {
        case .real:
            return true
        case .watch, .hardware:
            return false
        }
    }

    private func isShowingExceededThresholdPrompt(wallet: Wallet) -> Bool {
        guard let prompt = readState()?.prompt[wallet.address] else { return false }
        switch prompt {
        case .balanceExceededThreshold:
            return true
        case .newWallet, .intervalPassed, .receivedNativeCryptoCurrency:
            return false
        }
    }

    private func timeToShowIntervalPassedPrompt(wallet: Wallet) -> Date? {
        return readState()?.backupState[wallet.address]?.timeToShowIntervalPassedPrompt
    }

    public func securityLevel(wallet: Wallet) -> WalletSecurityLevel? {
        switch wallet.type {
        case .real(let account):
            if isBackedUp(wallet: wallet) || isImported(wallet: wallet) {
                let isProtectedByUserPresence = keystore.isProtectedByUserPresence(account: account)
                if isProtectedByUserPresence {
                    return .backedUpWithElevatedSecurity
                } else {
                    return .backedUpButSecurityIsNotElevated
                }
            } else {
                return .notBackedUp
            }
        case .watch, .hardware:
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

extension PromptBackup {
    public enum PromptEvent {
        public static func == (lhs: PromptBackup.PromptEvent, rhs: Wallet) -> Bool {
            switch lhs {
            case .hideBackupView(let w):
                return w == rhs
            case .show(let w, _):
                return w == rhs
            }
        }

        case show(wallet: Wallet, prompt: WalletsBackupState.Prompt)
        case hideBackupView(wallet: Wallet)
    }
}

