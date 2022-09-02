//
//  RenameWalletViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 31.03.2021.
//

import Foundation
import Combine
import AlphaWalletFoundation

class RenameWalletViewModel {
    let account: AlphaWallet.Address

    var title: String {
        return R.string.localizable.settingsWalletRename()
    }

    var saveWalletNameTitle: String {
        return R.string.localizable.walletRenameSave()
    }

    var walletNameTitle: String {
        return R.string.localizable.walletRenameEnterNameTitle()
    }

    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainResolutionServiceType

    init(account: AlphaWallet.Address, analytics: AnalyticsLogger, domainResolutionService: DomainResolutionServiceType) {
        self.account = account
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
    }

    func set(walletName: String) {
        FileWalletStorage().addOrUpdate(name: walletName, for: account)
        analytics.log(action: Analytics.Action.nameWallet)
    }

    var resolvedEns: AnyPublisher<String?, Never> {
        return domainResolutionService.resolveEns(address: account)
            .map { ens -> EnsName? in return ens }
            .replaceError(with: nil)
            .eraseToAnyPublisher()
    }

    var assignedName: AnyPublisher<String?, Never> {
        let name = FileWalletStorage().name(for: account)
        return .just(name)
    }
}
