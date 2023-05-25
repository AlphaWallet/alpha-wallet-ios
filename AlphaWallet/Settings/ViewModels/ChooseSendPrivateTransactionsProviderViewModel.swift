// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation
import Combine

struct ChooseSendPrivateTransactionsProviderViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
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

        let providers = input.willAppear
            .map { _ in self.providers }

        let viewState = Publishers.CombineLatest(providers, selection)
            .map { providers, selection -> [SelectionTableViewCellModel] in
                return providers.map { .init(titleText: $0.title, icon: $0.icon, value: .just(selection == $0)) }
            }.map { self.buildSnapshot(for: $0) }
            .map { ChooseSendPrivateTransactionsProviderViewModel.ViewState(snapshot: $0) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    private func buildSnapshot(for viewModels: [SelectionTableViewCellModel]) -> Snapshot {
        var snapshot = Snapshot()
        snapshot.appendSections(ChooseSendPrivateTransactionsProviderViewModel.Section.allCases)
        snapshot.appendItems(viewModels)

        return snapshot
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
    class DataSource: UITableViewDiffableDataSource<ChooseSendPrivateTransactionsProviderViewModel.Section, SelectionTableViewCellModel> {}
    typealias Snapshot = NSDiffableDataSourceSnapshot<ChooseSendPrivateTransactionsProviderViewModel.Section, SelectionTableViewCellModel>

    enum Section: Int, Hashable, CaseIterable {
        case providers
    }
    
    struct ViewState {
        let title: String = R.string.localizable.settingsChooseSendPrivateTransactionsProviderButtonTitle()
        let snapshot: Snapshot
    }
}
