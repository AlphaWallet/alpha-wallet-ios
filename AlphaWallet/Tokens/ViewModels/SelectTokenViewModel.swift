//
//  SelectTokenViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit
import Combine

struct SelectTokenViewModelInput {
    let appear: AnyPublisher<Void, Never>
    let fetch: AnyPublisher<Void, Never>
}

struct SelectTokenViewModelOutput {
    let viewModels: AnyPublisher<[SelectTokenViewModel.ViewModelType], Never>
    let loadingState: AnyPublisher<SelectTokenViewModel.LoadingState, Never>
}

final class SelectTokenViewModel {
    private let filter: WalletFilter
    private let tokenCollection: TokenCollection
    private var cancelable = Set<AnyCancellable>()
    private var selectedToken: TokenViewModel?
    private var filteredTokens: [TokenViewModel] = []
    private let tokensFilter: TokensFilter
    
    var headerBackgroundColor: UIColor = Colors.appBackground
    var navigationTitle: String = R.string.localizable.assetsSelectAssetTitle()
    var backgroundColor: UIColor = Colors.appBackground

    init(tokenCollection: TokenCollection, tokensFilter: TokensFilter, filter: WalletFilter) {
        self.tokenCollection = tokenCollection
        self.tokensFilter = tokensFilter
        self.filter = filter
    }

    func selectTokenViewModel(at indexPath: IndexPath) -> Token? {
        let token = tokenViewModel(at: indexPath)
        selectedToken = token

        return tokenCollection.token(for: token.contractAddress, server: token.server)
    }

    func numberOfItems() -> Int {
        return filteredTokens.count
    }

    func transform(input: SelectTokenViewModelInput) -> SelectTokenViewModelOutput {
        let loadingState: PassthroughSubject<LoadingState, Never> = .init()

        input.appear.merge(with: input.fetch).sink { [tokenCollection, loadingState] _ in
            loadingState.send(.beginLoading)
            tokenCollection.refresh()
        }.store(in: &cancelable)

        let tokens = tokenCollection.tokenViewModels
            .map { [tokensFilter, filter] tokens -> [TokenViewModel] in
                let displayedTokens = tokensFilter.filterTokens(tokens: tokens, filter: filter)
                return tokensFilter.sortDisplayedTokens(tokens: displayedTokens)
            }.handleEvents(receiveOutput: { tokens in
                self.filteredTokens = tokens
            }).map { tokens -> [ViewModelType] in
                return tokens.map { token -> SelectTokenViewModel.ViewModelType in
                    let accessoryType = self.accessoryType(for: token)
                    switch token.type {
                    case .nativeCryptocurrency:
                        let viewModel = EthTokenViewCellViewModel(token: token, accessoryType: accessoryType)
                        return .nativeCryptocurrency(viewModel)
                    case .erc20:
                        let viewModel = FungibleTokenViewCellViewModel(token: token, accessoryType: accessoryType)
                        return .fungible(viewModel)
                    case .erc721, .erc721ForTickets, .erc875, .erc1155:
                        let viewModel = NonFungibleTokenViewCellViewModel(token: token, accessoryType: accessoryType)
                        return .nonFungible(viewModel)
                    }
                }
            }.handleEvents(receiveOutput: { [loadingState] _ in
                loadingState.send(.endLoading)
            }).removeDuplicates()

        return .init(viewModels: tokens.eraseToAnyPublisher(),
                     loadingState: loadingState.merge(with: Just(.idle)).eraseToAnyPublisher())
    }

    private func accessoryType(for token: TokenViewModel) -> UITableViewCell.AccessoryType {
        guard let selectedToken = selectedToken else { return .none }

        return selectedToken == token ? .checkmark : .none
    }

    private func tokenViewModel(at indexPath: IndexPath) -> TokenViewModel {
        return filteredTokens[indexPath.row]
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
    }

    enum LoadingState {
        case idle
        case beginLoading
        case endLoading
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
