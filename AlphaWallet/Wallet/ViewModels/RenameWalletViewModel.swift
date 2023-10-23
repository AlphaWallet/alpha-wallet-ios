//
//  RenameWalletViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 31.03.2021.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletENS
import AlphaWalletFoundation

struct RenameWalletViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
    let walletName: AnyPublisher<String, Never>
}

struct RenameWalletViewModelOutput {
    let walletNameSaved: AnyPublisher<Void, Never>
    let viewState: AnyPublisher<RenameWalletViewModel.ViewState, Never>
}

final class RenameWalletViewModel {
    private let account: AlphaWallet.Address
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainNameResolutionServiceType

    init(account: AlphaWallet.Address, analytics: AnalyticsLogger, domainResolutionService: DomainNameResolutionServiceType) {
        self.account = account
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
    }

    func transform(input: RenameWalletViewModelInput) -> RenameWalletViewModelOutput {
        let walletNameSaved = input.walletName
            .handleEvents(receiveOutput: { self.set(walletName: $0) })
            .mapToVoid()
            .eraseToAnyPublisher()

        let assignedName = input.willAppear.map { _ in FileWalletStorage().name(for: self.account) }

        let resolvedEns: Future<DomainName?, Never> = asFuture { () -> DomainName? in
            (try? await self.domainResolutionService.reverseResolveDomainName(address: self.account, server: RPCServer.forResolvingDomainNames)) ?? nil
        }
        let viewState = Publishers.CombineLatest(assignedName, resolvedEns)
            .map { RenameWalletViewModel.ViewState(text: $0.0, placeholder: $0.1) }
            .eraseToAnyPublisher()

        return .init(walletNameSaved: walletNameSaved, viewState: viewState)
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
        let title: String = R.string.localizable.settingsWalletRename()
    }
}
