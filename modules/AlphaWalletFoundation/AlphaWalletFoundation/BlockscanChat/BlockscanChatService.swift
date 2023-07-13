// Copyright © 2022 Stormbird PTE. LTD.

import Combine
import Foundation
import AlphaWalletCore
import AlphaWalletLogger

public protocol BlockscanChatServiceDelegate: AnyObject {
    func openBlockscanChat(url: URL, for: BlockscanChatService)
    func showBlockscanUnreadCount(_ count: Int?, for: BlockscanChatService)
}

public class BlockscanChatService {
    private static let refreshInterval: TimeInterval = 60
    private let networkService: NetworkService
    private let account: Wallet
    private var blockscanChatsForRealWallets: [BlockscanChat]
    private let keystore: Keystore
    private let analytics: AnalyticsLogger
    private var cancelable = Set<AnyCancellable>()
    private var periodicRefreshTimer: Timer?
    private var realWalletAddresses: [AlphaWallet.Address] {
        keystore.wallets.compactMap {
            switch $0.type {
            case .real(let address), .hardware(let address):
                return address
            case .watch:
                return nil
            }
        }
    }

    public weak var delegate: BlockscanChatServiceDelegate?

    public init(keystore: Keystore, account: Wallet, analytics: AnalyticsLogger, networkService: NetworkService) {
        self.blockscanChatsForRealWallets = []
        self.keystore = keystore
        self.account = account
        self.analytics = analytics
        self.networkService = networkService
        watchForWalletChanges()
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        periodicRefreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            self?.periodicallyRefreshUnreadCountForCurrentWallet()
        }
    }
    deinit {
        verboseLog("[BlockscanChat] BlockscanChatService deinit")
        periodicRefreshTimer?.invalidate()
    }

    private func configureBlockscanChats() {
        blockscanChatsForRealWallets = realWalletAddresses.map { BlockscanChat(networkService: networkService, address: $0) }
    }

    private func refreshUnreadCount(forBlockscanChat blockscanChat: BlockscanChat) {
        let isCurrentRealAccount = account.address == blockscanChat.address

        guard Features.current.isAvailable(.isBlockscanChatEnabled) else { return }
        guard !Constants.Credentials.blockscanChatProxyKey.isEmpty else { return }

        blockscanChat
            .fetchUnreadCount()
            .sink(receiveCompletion: { [weak self] result in
                guard let strongSelf = self else { return }
                guard case .failure(let error) = result else { return }

                switch error {
                case .statusCode(let code) where code == 429:
                    strongSelf.logUnreadAnalytics(resultType: Analytics.BlockscanChatResultType.error429)
                case .statusCode, .other:
                    strongSelf.logUnreadAnalytics(resultType: Analytics.BlockscanChatResultType.errorOthers)
                }

                if isCurrentRealAccount {
                    strongSelf.delegate?.showBlockscanUnreadCount(nil, for: strongSelf)
                }
            }, receiveValue: { [weak self] unreadCount in
                guard let strongSelf = self else { return }

                if unreadCount > 0 {
                    strongSelf.logUnreadAnalytics(resultType: Analytics.BlockscanChatResultType.nonZero)
                } else {
                    strongSelf.logUnreadAnalytics(resultType: Analytics.BlockscanChatResultType.zero)
                }
                if isCurrentRealAccount {
                    strongSelf.delegate?.showBlockscanUnreadCount(unreadCount, for: strongSelf)
                }
            }).store(in: &cancelable)
    }

    public func openBlockscanChat(forAddress address: AlphaWallet.Address) {
        let isCurrentRealAccount = account.address == address
        guard isCurrentRealAccount else { return }
        delegate?.openBlockscanChat(url: Constants.BlockscanChat.blockscanChatWebUrl.appendingPathComponent(address.eip55String), for: self)
        let delayForUserToClearChats: Double = 10
        DispatchQueue.main.asyncAfter(deadline: .now() + delayForUserToClearChats) { [weak self] in
            self?.refreshUnreadCountForCurrentWallet()
        }
    }

    private func watchForWalletChanges() {
        keystore
                .walletsPublisher
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    guard let strongSelf = self else { return }
                    strongSelf.configureBlockscanChats()
                    strongSelf.refreshUnreadCountsForAllWallets()
                }.store(in: &cancelable)
    }

    //TODO display unread count in Accounts for all users if non-zero?
    private func refreshUnreadCountsForAllWallets() {
        var delay: Double = 0
        let increments: Double = 0.2
        for each in realWalletAddresses {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.getBlockscanChat(forAddress: each).flatMap { self?.refreshUnreadCount(forBlockscanChat: $0) }
            }
            delay += increments
        }
    }

    private func periodicallyRefreshUnreadCountForCurrentWallet() {
        infoLog("[BlockscanChat] periodicallyRefreshUnreadCountForCurrentWallet wallet: \(account.address.eip55String)")
        //TODO refresh for all wallets (maybe less often as the current wallet). Not doing it yet because we don't have a way to show the unread count for inactive wallets
        refreshUnreadCountForCurrentWallet()
    }

    private func refreshUnreadCountForCurrentWallet() {
        getBlockscanChat(forAddress: account.address).flatMap { refreshUnreadCount(forBlockscanChat: $0) }
    }

    private func getBlockscanChat(forAddress: AlphaWallet.Address) -> BlockscanChat? {
        blockscanChatsForRealWallets.first { $0.address == forAddress }
    }
}

// MARK: Application State
extension BlockscanChatService {
    @objc private func applicationWillEnterForeground(_ notification: Notification) {
        refreshUnreadCountsForAllWallets()
    }
}

// MARK: Analytics
extension BlockscanChatService {
    private func logUnreadAnalytics(resultType: Analytics.BlockscanChatResultType) {
        analytics.log(stat: Analytics.Stat.blockscanChatFetchUnread, properties: [Analytics.Properties.resultType.rawValue: resultType.rawValue])
    }
}
