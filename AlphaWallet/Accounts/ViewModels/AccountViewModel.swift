// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import Combine

class AccountViewModel {
    private let getWalletName: GetWalletName
    private let blockiesGenerator: BlockiesGenerator
    private let subscribeForBalanceUpdates: Bool
    private let walletBalanceService: WalletBalanceService
    private let analyticsCoordinator: AnalyticsCoordinator
    private let wallet: Wallet
    private let current: Wallet?

    lazy var apprecation24hour: AnyPublisher<NSAttributedString, Never> = {
        let initialApprecation24hour = apprecation24hourAttributedString(walletBalanceService.walletBalance(wallet: wallet))

        return walletBalanceService
            .walletBalancePublisher(wallet: wallet)
            .compactMap { [weak self] in self?.apprecation24hourAttributedString($0) }
            .receive(on: RunLoop.main)
            .prepend(initialApprecation24hour)
            .eraseToAnyPublisher()
    }()

    lazy var balance: AnyPublisher<NSAttributedString, Never> = {
        let initialBalance = balanceAttributedString(walletBalanceService.walletBalance(wallet: wallet).totalAmountString)

        return walletBalanceService.walletBalancePublisher(wallet: wallet)
            .compactMap { [weak self] in self?.balanceAttributedString($0.totalAmountString) }
            .receive(on: RunLoop.main)
            .prepend(initialBalance)
            .eraseToAnyPublisher()
    }()

    lazy var blockieImage: AnyPublisher<BlockiesImage, Never> = {
        return blockiesGenerator.getBlockie(address: wallet.address)
            .handleEvents(receiveOutput: { [weak self] value in
                guard value.isEnsAvatar else { return }
                self?.analyticsCoordinator.setUser(property: Analytics.UserProperties.hasEnsAvatar, value: true)
            })
            .eraseToAnyPublisher()
    }()

    lazy var addressOrEnsName: AnyPublisher<NSAttributedString, Never> = {
        let address = wallet.address

        return getWalletName.getName(forAddress: address).publisher
            .map { ensOrName in "\(ensOrName) | \(address.truncateMiddle)" }
            .receive(on: RunLoop.main)
            .replaceError(with: address.eip55String)
            .prepend(address.eip55String)
            .compactMap { [weak self] value in self?.addressOrEnsOrNameAttributedString(value) }
            .eraseToAnyPublisher()
    }()

    init(
        analyticsCoordinator: AnalyticsCoordinator,
        getWalletName: GetWalletName,
        blockiesGenerator: BlockiesGenerator,
        subscribeForBalanceUpdates: Bool,
        walletBalanceService: WalletBalanceService,
        wallet: Wallet,
        current: Wallet?
    ) {
        self.analyticsCoordinator = analyticsCoordinator
        self.wallet = wallet
        self.current = current
        self.getWalletName = getWalletName
        self.blockiesGenerator = blockiesGenerator
        self.subscribeForBalanceUpdates = subscribeForBalanceUpdates
        self.walletBalanceService = walletBalanceService
    }

    var showWatchIcon: Bool {
        return wallet.type == .watch(wallet.address)
    }

    var isSelected: Bool {
        return wallet == current
    }

    var backgroundColor: UIColor = Colors.appBackground

    private func apprecation24hourAttributedString(_ balance: WalletBalance?) -> NSAttributedString {
        if subscribeForBalanceUpdates {
            let style = NSMutableParagraphStyle()
            style.alignment = .right

            return .init(string: balance?.valuePercentageChangeValue ?? "-", attributes: [
                .font: Fonts.regular(size: 20),
                .foregroundColor: balance?.valuePercentageChangeColor ?? R.color.dove()!,
                .paragraphStyle: style
            ])
        } else {
            return .init()
        }
    }

    private func balanceAttributedString(_ value: String?) -> NSAttributedString {
        return .init(string: value ?? "--", attributes: [
            .font: Fonts.bold(size: 20),
            .foregroundColor: Colors.black,
        ])
    }
    private func addressOrEnsOrNameAttributedString(_ name: String) -> NSAttributedString {
        return .init(string: name, attributes: [
            .font: Fonts.regular(size: 12),
            .foregroundColor: R.color.dove()!
        ])
    }
}
