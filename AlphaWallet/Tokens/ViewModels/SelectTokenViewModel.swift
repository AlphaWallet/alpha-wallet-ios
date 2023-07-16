//
//  SelectTokenViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit
import Combine
import AlphaWalletFoundation

struct SelectTokenViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
    let fetch: AnyPublisher<Void, Never>
}

struct SelectTokenViewModelOutput {
    let viewState: AnyPublisher<SelectTokenViewModel.ViewState, Never>
}

final class SelectTokenViewModel {
    private let filter: WalletFilter
    private let tokensPipeline: TokensProcessingPipeline
    private var cancelable = Set<AnyCancellable>()
    private let tokensFilter: TokensFilter
    private let whenFilterHasChanged: AnyPublisher<Void, Never>
    private let tokenImageFetcher: TokenImageFetcher
    private let tokensService: TokensService

    init(tokensPipeline: TokensProcessingPipeline,
         tokensFilter: TokensFilter,
         filter: WalletFilter,
         tokenImageFetcher: TokenImageFetcher,
         tokensService: TokensService) {

        self.tokensService = tokensService
        self.tokenImageFetcher = tokenImageFetcher
        self.tokensPipeline = tokensPipeline
        self.tokensFilter = tokensFilter
        self.filter = filter

        switch filter {
        case .filter(let extendedFilter):
            whenFilterHasChanged = extendedFilter.objectWillChange
        case .all, .attestations, .defi, .governance, .assets, .collectiblesOnly, .keyword:
            whenFilterHasChanged = Empty<Void, Never>(completeImmediately: true).eraseToAnyPublisher()
        }
    }

    func selectTokenViewModel(viewModel: SelectTokenViewModel.ViewModelType) async -> Token? {
        let value = viewModel.asTokenIdentifiable
        return await tokensService.token(for: value.contractAddress, server: value.server)
    }

    func transform(input: SelectTokenViewModelInput) -> SelectTokenViewModelOutput {
        let loadingState: CurrentValueSubject<LoadingState, Never> = .init(.idle)

        let whenAppearOrFetchOrFilterHasChanged = input.willAppear
            .merge(with: input.fetch, whenFilterHasChanged)
            .handleEvents(receiveOutput: { [loadingState] in
                loadingState.send(.beginLoading)
            }).flatMap { [tokensPipeline] _ in tokensPipeline.tokenViewModels.first() }

        let snapshot = tokensPipeline.tokenViewModels
            .merge(with: whenAppearOrFetchOrFilterHasChanged)
            .map { [tokensFilter, filter] tokens -> [TokenViewModel] in
                let displayedTokens = tokensFilter.filterTokens(tokens: tokens, filter: filter)
                return tokensFilter.sortDisplayedTokens(tokens: displayedTokens)
            }.map { self.buildViewModels(for: $0) }
            .handleEvents(receiveOutput: { [loadingState] _ in
                switch loadingState.value {
                case .beginLoading:
                    loadingState.send(.endLoading)
                case .endLoading, .idle:
                    break
                }
            }).removeDuplicates()
            .map { self.buildSnapshot(for: $0) }
            .eraseToAnyPublisher()

        let viewState = Publishers.CombineLatest(snapshot, loadingState.removeDuplicates())
            .map { SelectTokenViewModel.ViewState(snapshot: $0.0, loadingState: $0.1) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    private func buildSnapshot(for viewModels: [SelectTokenViewModel.ViewModelType]) -> SelectTokenViewModel.Snapshot {
        var snapshot = NSDiffableDataSourceSnapshot<SelectTokenViewModel.Section, SelectTokenViewModel.ViewModelType>()
        snapshot.appendSections([.tokens])
        snapshot.appendItems(viewModels, toSection: .tokens)

        return snapshot
    }

    private func buildViewModels(for tokens: [TokenViewModel]) -> [SelectTokenViewModel.ViewModelType] {
        return tokens.map { [tokenImageFetcher] token -> SelectTokenViewModel.ViewModelType in
            switch token.type {
            case .nativeCryptocurrency:
                let viewModel = EthTokenViewCellViewModel(token: token, tokenImageFetcher: tokenImageFetcher)
                return .nativeCryptocurrency(viewModel)
            case .erc20:
                let viewModel = FungibleTokenViewCellViewModel(token: token, tokenImageFetcher: tokenImageFetcher)
                return .fungible(viewModel)
            case .erc721, .erc721ForTickets, .erc875, .erc1155:
                let viewModel = NonFungibleTokenViewCellViewModel(token: token, tokenImageFetcher: tokenImageFetcher)
                return .nonFungible(viewModel)
            }
        }
    }
}

extension SelectTokenViewModel {
    enum Section: Int, CaseIterable {
        case tokens
    }

    enum ViewModelType {
        case nativeCryptocurrency(EthTokenViewCellViewModel)
        case fungible(FungibleTokenViewCellViewModel)
        case nonFungible(NonFungibleTokenViewCellViewModel)

        var asTokenIdentifiable: TokenIdentifiable {
            switch self {
            case .nativeCryptocurrency(let vm): return vm
            case .fungible(let vm): return vm
            case .nonFungible(let vm): return vm
            }
        }
    }

    enum LoadingState {
        case idle
        case beginLoading
        case endLoading
    }
    typealias Snapshot = NSDiffableDataSourceSnapshot<SelectTokenViewModel.Section, SelectTokenViewModel.ViewModelType>

    struct ViewState {
        let snapshot: Snapshot
        let loadingState: LoadingState
        let title: String = R.string.localizable.assetsSelectAssetTitle()
    }
}

extension SelectTokenViewModel.ViewModelType: Hashable {
    static func == (lhs: SelectTokenViewModel.ViewModelType, rhs: SelectTokenViewModel.ViewModelType) -> Bool {
        switch (lhs, rhs) {
        case (.nonFungible(let vm1), .nonFungible(let vm2)):
            return vm1 == vm2
        case (.fungible(let vm1), .fungible(let vm2)):
            return vm1 == vm2
        case (.nativeCryptocurrency(let vm1), .nativeCryptocurrency(let vm2)):
            return vm1 == vm2
        default:
            return false
        }
    }
}
