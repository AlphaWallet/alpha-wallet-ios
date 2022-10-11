//
//  RenameWalletViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 31.03.2021.
//

import Foundation
import Combine
import AlphaWalletFoundation

struct RenameWalletViewModelInput {
    let appear: AnyPublisher<Void, Never>
    let name: AnyPublisher<String, Never>
}

struct RenameWalletViewModelOutput {
    let viewState: AnyPublisher<RenameWalletViewModel.ViewState, Never>
}

final class RenameWalletViewModel {
    private let account: AlphaWallet.Address
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainResolutionServiceType
    private var cancelable = Set<AnyCancellable>()

    let title: String = R.string.localizable.settingsWalletRename()
    let saveWalletNameTitle: String = R.string.localizable.walletRenameSave()
    let walletNameTitle: String = R.string.localizable.walletRenameEnterNameTitle()

    init(account: AlphaWallet.Address, analytics: AnalyticsLogger, domainResolutionService: DomainResolutionServiceType) {
        self.account = account
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
    }

    func transform(input: RenameWalletViewModelInput) -> RenameWalletViewModelOutput {
        input.name
            .sink { self.set(walletName: $0) }
            .store(in: &cancelable)

        let assignedName = input.appear.map { _ in FileWalletStorage().name(for: self.account) }

        let resolvedEns = domainResolutionService.resolveEns(address: account)
            .map { ens -> EnsName? in return ens }
            .replaceError(with: nil)

        let viewState = Publishers.CombineLatest(assignedName, resolvedEns)
            .map { RenameWalletViewModel.ViewState(text: $0.0, placeholder: $0.1, title: self.title) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    private func set(walletName: String) {
        FileWalletStorage().addOrUpdate(name: walletName, for: account)
        analytics.log(action: Analytics.Action.nameWallet)
    }
}

extension RenameWalletViewModel {
    struct ViewState {
        let text: String?
        let placeholder: String?
        let title: String
    }
}
