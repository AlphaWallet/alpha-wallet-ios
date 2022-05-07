// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import Combine

class AccountViewModel {
    private let domainResolver: DomainResolutionServiceType
    private let generator: BlockiesGenerator
    private let subscribeForBalanceUpdates: Bool
    private let walletBalanceService: WalletBalanceService
    private let config: Config
    private let analyticsCoordinator: AnalyticsCoordinator
    private let wallet: Wallet
    private let current: Wallet?

    lazy var apprecation24hour: AnyPublisher<NSAttributedString, Never> = {
        let initialApprecation24hour = apprecation24hourAttributedString(for: walletBalanceService.walletBalance(wallet: wallet))
        
        return walletBalanceService
            .walletBalancePublisher(wallet: wallet)
            .compactMap { [weak self] in self?.apprecation24hourAttributedString(for: $0) }
            .receive(on: RunLoop.main)
            .prepend(initialApprecation24hour)
            .eraseToAnyPublisher()
    }()

    lazy var balance: AnyPublisher<NSAttributedString, Never> = {
        let initialBalance = balanceAttributedString(for: walletBalanceService.walletBalance(wallet: wallet).totalAmountString)

        return walletBalanceService.walletBalancePublisher(wallet: wallet)
            .compactMap { [weak self] in self?.balanceAttributedString(for: $0.totalAmountString) }
            .receive(on: RunLoop.main)
            .prepend(initialBalance)
            .eraseToAnyPublisher()
    }()
    
    lazy var blockieImage: AnyPublisher<BlockiesImage, Never> = {
        return generator.getBlockie(address: wallet.address)
            .handleEvents(receiveOutput: { [weak self] value in
                guard value.isEnsAvatar else { return }
                self?.analyticsCoordinator.setUser(property: Analytics.UserProperties.hasEnsAvatar, value: true)
            })
            .eraseToAnyPublisher()
    }()

    lazy var addressesAttrinutedString: AnyPublisher<NSAttributedString, Never> = {
        return domainResolver.resolveEns(address: wallet.address).publisher
            .prepend((image: nil, resolution: .resolved(nil)))
            .replaceError(with: (image: nil, resolution: .resolved(nil)))
            .map { $0.resolution.value }
            .compactMap { [weak self] in self?.addressAttributedString(ensName: $0) }
            .receive(on: RunLoop.main)
            .prepend(addressAttributedString(ensName: nil))
            .eraseToAnyPublisher()
    }()

    init(
        analyticsCoordinator: AnalyticsCoordinator,
        domainResolver: DomainResolutionServiceType,
        generator: BlockiesGenerator,
        subscribeForBalanceUpdates: Bool,
        walletBalanceService: WalletBalanceService,
        config: Config,
        wallet: Wallet,
        current: Wallet?
    ) {
        self.analyticsCoordinator = analyticsCoordinator
        self.wallet = wallet
        self.current = current
        self.config = config
        self.domainResolver = domainResolver
        self.generator = generator
        self.subscribeForBalanceUpdates = subscribeForBalanceUpdates
        self.walletBalanceService = walletBalanceService
    }

    var showWatchIcon: Bool {
        return wallet.type == .watch(wallet.address)
    } 

    var isSelected: Bool {
        return wallet == current
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    private func apprecation24hourAttributedString(for balance: WalletBalance?) -> NSAttributedString {
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

    private func balanceAttributedString(for value: String?) -> NSAttributedString {
        return .init(string: value ?? "--", attributes: [
            .font: Fonts.bold(size: 20),
            .foregroundColor: Colors.black,
        ])
    }

    private func addressAttributedString(ensName: String?) -> NSAttributedString {
        return .init(string: formattedAddressName(ensName: ensName), attributes: [
            .font: Fonts.regular(size: 12),
            .foregroundColor: R.color.dove()!
        ])
    }

    private func formattedAddressName(ensName: String?) -> String {
        if let walletName = config.walletNames[wallet.address] {
            return "\(walletName) | \(wallet.address.truncateMiddle)"
        } else if let ensName = ensName {
            return "\(ensName) | \(wallet.address.truncateMiddle)"
        } else {
            return wallet.address.eip55String
        }
    }
} 
