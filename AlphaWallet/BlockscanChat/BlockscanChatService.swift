// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import PromiseKit

protocol BlockscanChatServiceDelegate: class {
    func openBlockscanChat(url: URL, for: BlockscanChatService)
    func showBlockscanUnreadCount(_ count: Int?, for: BlockscanChatService)
}

class BlockscanChatService {
    private let blockscanChat: BlockscanChat?
    private let account: Wallet
    private let analyticsCoordinator: AnalyticsCoordinator

    weak var delegate: BlockscanChatServiceDelegate?

    init(account: Wallet, analyticsCoordinator: AnalyticsCoordinator) {
        self.account = account
        self.analyticsCoordinator = analyticsCoordinator
        switch account.type {
        case .real(let address):
            blockscanChat = BlockscanChat(address: address)
        case .watch:
            blockscanChat = nil
        }
    }

    func refreshUnreadCount() {
        guard Features.isBlockscanChatEnabled else { return }
        guard !Constants.Credentials.blockscanChatProxyKey.isEmpty else { return }
        if let blockscanChat = blockscanChat {
            firstly {
                blockscanChat.fetchUnreadCount()
            }.done { [weak self] unreadCount in
               guard let strongSelf = self else { return }
                if unreadCount > 0 {
                    strongSelf.logUnreadAnalytics(resultType: Analytics.BlockscanChatResultType.nonZero)
                } else {
                    strongSelf.logUnreadAnalytics(resultType: Analytics.BlockscanChatResultType.zero)
                }
                strongSelf.delegate?.showBlockscanUnreadCount(unreadCount, for: strongSelf)
            }.catch { [weak self] error in
                guard let strongSelf = self else { return }
                if let error = error as? AFError, let code = error.responseCode, code == 429 {
                    strongSelf.logUnreadAnalytics(resultType: Analytics.BlockscanChatResultType.error429)
                } else {
                    strongSelf.logUnreadAnalytics(resultType: Analytics.BlockscanChatResultType.errorOthers)
                }
                strongSelf.delegate?.showBlockscanUnreadCount(nil, for: strongSelf)
            }
        } else {
            delegate?.showBlockscanUnreadCount(nil, for: self)
        }
    }

    func openBlockscanChat() {
        delegate?.openBlockscanChat(url: Constants.BlockscanChat.blockscanChatWebUrl.appendingPathComponent(account.address.eip55String), for: self)
        //We refresh since the user might have cleared their unread messages after we point them to the chat dapp
        if let n = blockscanChat?.lastKnownCount, n > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                self?.refreshUnreadCount()
            }
        }
    }
}

//MARK: Analytics
extension BlockscanChatService {
    private func logUnreadAnalytics(resultType: Analytics.BlockscanChatResultType) {
        analyticsCoordinator.log(stat: Analytics.Stat.blockscanChatFetchUnread, properties: [Analytics.Properties.resultType.rawValue: resultType.rawValue])
    }
}