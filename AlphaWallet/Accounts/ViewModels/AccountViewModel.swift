// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import Combine
import AlphaWalletFoundation

class AccountViewModel {
    private let getWalletName: GetWalletName
    private let blockiesGenerator: BlockiesGenerator
    private let subscribeForBalanceUpdates: Bool
    private let walletBalanceService: WalletBalanceService
    private let analytics: AnalyticsLogger
    private let current: Wallet?

    let wallet: Wallet
    lazy var apprecation24hour: AnyPublisher<NSAttributedString, Never> = {
        return walletBalanceService
            .walletBalance(for: wallet)
            .compactMap { [weak self] in self?.apprecation24hourAttributedString($0) }
            .eraseToAnyPublisher()
    }()

    lazy var balance: AnyPublisher<NSAttributedString, Never> = {
        return walletBalanceService.walletBalance(for: wallet)
            .compactMap { [weak self] in self?.balanceAttributedString($0.totalAmountString) }
            .eraseToAnyPublisher()
    }()

    lazy var blockieImage: AnyPublisher<BlockiesImage, Never> = {
        return blockiesGenerator.getBlockieOrEnsAvatarImage(address: wallet.address, fallbackImage: BlockiesImage.defaulBlockieImage)
            .handleEvents(receiveOutput: { [weak self] value in
                guard value.isEnsAvatar else { return }
                self?.analytics.setUser(property: Analytics.UserProperties.hasEnsAvatar, value: true)
            }).eraseToAnyPublisher()
    }()

    lazy var addressOrEnsName: AnyPublisher<NSAttributedString, Never> = {
        return getWalletName.assignedNameOrEns(for: wallet.address)
            .map { [wallet] ensOrName in
                if let ensOrName = ensOrName {
                    return "\(ensOrName) | \(wallet.address.truncateMiddle)"
                } else {
                    return wallet.address.eip55String
                }
            }.prepend(wallet.address.eip55String)
            .compactMap { [weak self] value in self?.addressOrEnsOrNameAttributedString(value) }
            .eraseToAnyPublisher()
    }()

    init(
        analytics: AnalyticsLogger,
        getWalletName: GetWalletName,
        blockiesGenerator: BlockiesGenerator,
        subscribeForBalanceUpdates: Bool,
        walletBalanceService: WalletBalanceService,
        wallet: Wallet,
        current: Wallet?
    ) {
        self.analytics = analytics
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

    var backgroundColor: UIColor = Configuration.Color.Semantic.defaultViewBackground

    var canEditCell: Bool {
        return !isSelected
    }

    private func apprecation24hourAttributedString(_ balance: WalletBalance?) -> NSAttributedString {
        if subscribeForBalanceUpdates {
            let style = NSMutableParagraphStyle()
            style.alignment = .right

            return .init(string: balance?.valuePercentageChangeValue ?? "-", attributes: [
                .font: Fonts.regular(size: 20),
                .foregroundColor: balance?.valuePercentageChangeColor ?? Configuration.Color.Semantic.defaultAttributedString,
                .paragraphStyle: style
            ])
        } else {
            return .init()
        }
    }

    private func balanceAttributedString(_ value: String?) -> NSAttributedString {
        return .init(string: value ?? "--", attributes: [
            .font: Fonts.bold(size: 20),
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText,
        ])
    }
    
    private func addressOrEnsOrNameAttributedString(_ name: String) -> NSAttributedString {
        return .init(string: name, attributes: [
            .font: Fonts.regular(size: 12),
            .foregroundColor: Configuration.Color.Semantic.defaultAttributedString
        ])
    }
}

extension BlockiesImage {
    static var defaulBlockieImage: BlockiesImage {
        return .image(image: R.image.tokenPlaceholderLarge()!, isEnsAvatar: false)
    }
}

extension WalletBalance {
    var valuePercentageChangeColor: UIColor {
        return BalanceHelper().valueChangeValueColor(from: changeDouble)
    }
}
