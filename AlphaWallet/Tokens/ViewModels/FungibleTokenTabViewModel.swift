//
//  FungibleTokenTabViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.11.2022.
//

import UIKit
import AlphaWalletFoundation
import Combine

struct FungibleTokenTabViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
}

struct FungibleTokenTabViewModelOutput {
    let viewState: AnyPublisher<FungibleTokenTabViewModel.ViewState, Never>
}

class FungibleTokenTabViewModel {
    private let token: Token
    private let tokensPipeline: TokensProcessingPipeline
    private let assetDefinitionStore: AssetDefinitionStore
    private var cancelable = Set<AnyCancellable>()
    private let tokensService: TokensService
    lazy var tokenScriptFileStatusHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)

    let session: WalletSession
    let tabBarItems: [TabBarItem]

    init(token: Token,
         session: WalletSession,
         tokensPipeline: TokensProcessingPipeline,
         assetDefinitionStore: AssetDefinitionStore,
         tokensService: TokensService) {

        self.tokensService = tokensService
        self.tokensPipeline = tokensPipeline
        self.assetDefinitionStore = assetDefinitionStore
        self.token = token
        self.session = session

        let hasTicker = tokensPipeline.tokenViewModel(for: token)?.balance.ticker != nil

        if Features.current.isAvailable(.isAlertsEnabled) && hasTicker {
            tabBarItems = [.details, .activities, .alerts]
        } else {
            tabBarItems = [.details, .activities]
        }
    }

    func transform(input: FungibleTokenTabViewModelInput) -> FungibleTokenTabViewModelOutput {
        input.willAppear
            .sink { [tokensService, token] _ in
                tokensService.refreshBalance(updatePolicy: .token(token: token))
            }.store(in: &cancelable)

        let viewState = tokensPipeline
            .tokenViewModelPublisher(for: token)
            .map { $0?.tokenScriptOverrides?.titleInPluralForm }
            .map { FungibleTokenTabViewModel.ViewState(title: $0) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState)
    }
}

extension FungibleTokenTabViewModel {
    enum TabBarItem: CustomStringConvertible {
        case details
        case activities
        case alerts

        var description: String {
            switch self {
            case .details: return R.string.localizable.tokenTabInfo()
            case .activities: return R.string.localizable.tokenTabActivity()
            case .alerts: return R.string.localizable.priceAlertNavigationTitle()
            }
        }
    }

    struct ViewState {
        let title: String?
    }
}
