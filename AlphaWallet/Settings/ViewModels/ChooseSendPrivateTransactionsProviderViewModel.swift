// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation
import Combine

struct ChooseSendPrivateTransactionsProviderViewModelInput {
    let appear: AnyPublisher<Void, Never>
    let selection: AnyPublisher<IndexPath, Never>
}

struct ChooseSendPrivateTransactionsProviderViewModelOutput {
    let viewState: AnyPublisher<ChooseSendPrivateTransactionsProviderViewModel.ViewState, Never>
}

class ChooseSendPrivateTransactionsProviderViewModel {
    private var config: Config
    private let providers: [SendPrivateTransactionsProvider] = SendPrivateTransactionsProvider.allCases

    init(config: Config) {
        self.config = config
    }

    func transform(input: ChooseSendPrivateTransactionsProviderViewModelInput) -> ChooseSendPrivateTransactionsProviderViewModelOutput {
        let selection = input.selection
            .map { return self.selectProvider(indexPath: $0) }
            .prepend(config.sendPrivateTransactionsProvider)

        let providers = input.appear
            .map { _ in self.providers }

        let viewState = Publishers.CombineLatest(providers, selection)
            .map { providers, selection -> [SwitchTableViewCellViewModel] in
                return providers.map { row in
                    .init(titleText: row.title, icon: row.icon, value: selection == row)
                }
            }.map { viewModels -> Snapshot in
                var snapshot = Snapshot()
                snapshot.appendSections(ChooseSendPrivateTransactionsProviderViewModel.Section.allCases)
                snapshot.appendItems(viewModels)

                return snapshot
            }.map { ChooseSendPrivateTransactionsProviderViewModel.ViewState(title: R.string.localizable.settingsChooseSendPrivateTransactionsProviderButtonTitle(), largeTitleDisplayMode: .never, snapshot: $0)
            }.eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    private func selectProvider(indexPath: IndexPath) -> SendPrivateTransactionsProvider? {
        let provider = providers[indexPath.row]
        let chosenProvider: SendPrivateTransactionsProvider?
        if provider == config.sendPrivateTransactionsProvider {
            chosenProvider = nil
        } else {
            chosenProvider = provider
        }
        config.sendPrivateTransactionsProvider = chosenProvider

        return chosenProvider
    }

}

extension ChooseSendPrivateTransactionsProviderViewModel {
    class DataSource: UITableViewDiffableDataSource<ChooseSendPrivateTransactionsProviderViewModel.Section, SwitchTableViewCellViewModel> {}
    typealias Snapshot = NSDiffableDataSourceSnapshot<ChooseSendPrivateTransactionsProviderViewModel.Section, SwitchTableViewCellViewModel>

    enum Section: Int, Hashable, CaseIterable {
        case providers
    }
    
    struct ViewState {
        let title: String
        let largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode
        let snapshot: Snapshot
    }
}
