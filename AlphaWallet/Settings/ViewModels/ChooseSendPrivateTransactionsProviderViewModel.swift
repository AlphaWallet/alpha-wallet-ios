// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation
import Combine

struct ChooseSendPrivateTransactionsProviderViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
    let selection: AnyPublisher<IndexPath, Never>
}

struct ChooseSendPrivateTransactionsProviderViewModelOutput {
    let privateTransactionsProviderChanged: AnyPublisher<Void, Never>
    let viewState: AnyPublisher<ChooseSendPrivateTransactionsProviderViewModel.ViewState, Never>
}

class ChooseSendPrivateTransactionsProviderViewModel {
    private var config: Config
    private let providers: [SendPrivateTransactionsProvider] = SendPrivateTransactionsProvider.allCases

    init(config: Config) {
        self.config = config
    }

    func transform(input: ChooseSendPrivateTransactionsProviderViewModelInput) -> ChooseSendPrivateTransactionsProviderViewModelOutput {
        let selectProvider = input.selection
            .map { return self.selectProvider(indexPath: $0) }
            .share()

        let selection = selectProvider
            .prepend(config.sendPrivateTransactionsProvider)

        let providers = input.willAppear
            .map { _ in self.providers }

        let viewState = Publishers.CombineLatest(providers, selection)
            .map { providers, selection -> [SwitchTableViewCellViewModel] in
                return providers.map { .init(titleText: $0.title, icon: $0.icon, value: selection == $0) }
            }.map { self.buildSnapshot(for: $0) }
            .map { ChooseSendPrivateTransactionsProviderViewModel.ViewState(snapshot: $0) }
            .eraseToAnyPublisher()
        let privateTransactionsProviderChanged = selectProvider
            .mapToVoid()
            .eraseToAnyPublisher()

        return .init(privateTransactionsProviderChanged: privateTransactionsProviderChanged, viewState: viewState)
    }

    private func buildSnapshot(for viewModels: [SwitchTableViewCellViewModel]) -> Snapshot {
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
    class DataSource: UITableViewDiffableDataSource<ChooseSendPrivateTransactionsProviderViewModel.Section, SwitchTableViewCellViewModel> {}
    typealias Snapshot = NSDiffableDataSourceSnapshot<ChooseSendPrivateTransactionsProviderViewModel.Section, SwitchTableViewCellViewModel>

    enum Section: Int, Hashable, CaseIterable {
        case providers
    }
    
    struct ViewState {
        let title: String = R.string.localizable.settingsChooseSendPrivateTransactionsProviderButtonTitle()
        let snapshot: Snapshot
    }
}
